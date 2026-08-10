#!/bin/bash
# モデル別の週次枠 (Fable など) を statusline に出すための実装。
#
# statusline.sh から source される前提で、単体実行はしません。
# 呼び出し側が用意しているものに依存します:
#   関数: bar() / color_for_pct()
#   変数: DIM / YELLOW / RESET
# 公開するのは print_model_limits() だけです。他は内部実装です。
#
# なぜ独立した取得が必要か:
# statusline の入力 JSON には five_hour / seven_day しか届きません。本体がその 2 つを
# anthropic-ratelimit-unified-{5h,7d}-* レスポンスヘッダから組み立てて渡しているためで、
# モデルスコープの週次枠 (Fable など) はヘッダ自体に存在せず、構造的に入ってきません。
# 唯一の取得元が Claude Code 本体の /usage コマンドと同じ内部 API (GET /api/oauth/usage) なので、
# 自分のアクセストークンでそれを直接叩き、60 秒キャッシュして使います。
# ドキュメント化されていないエンドポイントなので、フィールド名やパスが予告なく変わり得ます。
# 壊れても statusline の他の行に影響しないよう、失敗は全て黙って捨てています。

USAGE_CACHE_DIR="$HOME/.cache/claude-statusline"
USAGE_CACHE="$USAGE_CACHE_DIR/usage.json"
# 直近の試行マーカー。mkdir でアトミックに作るので、同時実行の防止と試行間隔の絞りを兼ねます
# (ファイルではなくディレクトリです。mkdir の成否がそのまま排他になるのが利点)
USAGE_ATTEMPT="$USAGE_CACHE_DIR/attempt.lock"
# 直近の取得結果。表示側がこれを読んで「取得できなかった」ことを画面に出します
USAGE_STATUS="$USAGE_CACHE_DIR/last-status"
USAGE_TTL=60        # キャッシュの寿命 = 試行間隔 (秒)

# weekly_scoped を含む配列をレスポンスから再帰的に探し出す jq フィルタ。
# 本体の実装を読むと limits 配列の位置は rate_limits の下とは限らないため、
# 階層を決め打ちせず「weekly_scoped を含む配列」を条件に探します。
# これならレスポンスの構造が変わっても、その配列が残っている限り拾えます。
USAGE_JQ_FIND='[ .. | arrays | select(any(.[]?; (.kind? // "") == "weekly_scoped")) ] | first // []'
# 見つけた配列から、モデル名を持つ weekly_scoped だけを残します
# (同じ配列に kind: session / weekly_all も入っており、それらは既存の Session / Weekly 行と重複します)
USAGE_JQ_SCOPED="$USAGE_JQ_FIND"' | map(select(((.kind? // "") == "weekly_scoped") and ((.scope.model.display_name // "") != "")))'

# epoch 秒までの残り時間を "3d5h20m" / "5h20m" 形式で返します。既に過ぎていれば空文字。
fmt_remain() {
  local target=$1 now diff d h m
  now=$(date +%s)
  diff=$((target - now))
  [ "$diff" -le 0 ] && return
  d=$((diff / 86400)); h=$(((diff % 86400) / 3600)); m=$(((diff % 3600) / 60))
  if [ "$d" -gt 0 ]; then printf '%dd%dh%dm' "$d" "$h" "$m"
  else printf '%dh%dm' "$h" "$m"; fi
}

# ファイルの mtime からの経過秒。取れなければ十分大きい値 (= 常に古い扱い) を返します。
file_age() {
  local m
  m=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null)
  case "$m" in (''|*[!0-9]*) printf '%s' 999999; return;; esac
  printf '%s' "$(( $(date +%s) - m ))"
}

# OAuth アクセストークンを取り出します。ファイルを優先します
# (Keychain を別プロセスから読むと認可ダイアログが出ることがあるため、無いときだけフォールバック)。
# ただし macOS では本体が更新し続けるのは Keychain 側で、ファイルは過去のログイン等の残骸が
# 放置されることがあります。期限切れのファイルトークンを優先し続けると 401 を返し続けるため、
# expiresAt (ミリ秒 epoch) を確かめて、切れていれば Keychain へフォールバックします。
read_access_token() {
  local t="" exp f="$HOME/.claude/.credentials.json"
  if [ -r "$f" ]; then
    t=$(jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$f" 2>/dev/null)
    exp=$(jq -r '.claudeAiOauth.expiresAt // .expiresAt // empty' "$f" 2>/dev/null)
    case "$exp" in
      (''|*[!0-9]*) ;;  # 期限が読めない形式ならそのまま使う (判定できないだけで有効かもしれない)
      (*) [ "${#exp}" -gt 10 ] && exp=${exp%???}   # ミリ秒 → 秒
          [ "$exp" -le "$(date +%s)" ] && t="" ;;
    esac
  fi
  if [ -z "$t" ]; then
    t=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
  fi
  printf '%s' "$t"
}

# 直近の取得結果を 1 行だけ記録します (上書きなので増え続けません)。
# 単なるログではなく状態ファイルです。表示側がこれを読んで「取得できなかった」ことを
# 画面に出すため、古い値を最新のものとして見せてしまう事故を防ぎます。
# 形式: <時刻>\t<OK|NG>\t<表示用の短い理由>\t<診断用の詳細>  トークンは書きません。
usage_log() {
  printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "${2:-}" "${3:-}" \
    > "$USAGE_STATUS" 2>/dev/null
}

# usage API を叩いてキャッシュを更新します。バックグラウンドから呼ばれる想定です。
# 失敗時はキャッシュを上書きしないので、復旧すればすぐ元の値に戻れます。
refresh_usage_cache() {
  local token tmp code reason
  token=$(read_access_token)
  [ -z "$token" ] && { usage_log NG 'トークン未取得'; return; }
  tmp="${USAGE_CACHE}.$$"
  code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 5 \
    -H 'Content-Type: application/json' \
    -H 'anthropic-beta: oauth-2025-04-20' \
    -H "Authorization: Bearer $token" \
    'https://api.anthropic.com/api/oauth/usage' 2>/dev/null)
  if [ "$code" != "200" ]; then
    # curl は接続できなかった場合 000 を返します (タイムアウト・DNS 失敗・ネットワーク断)
    case "$code" in
      000|'') reason='接続失敗' ;;
      *)      reason="HTTP $code" ;;
    esac
    usage_log NG "$reason"
    rm -f "$tmp" 2>/dev/null
    return
  fi
  # JSON オブジェクトとして妥当でエラーでないときだけ採用します (HTML やエラー JSON を弾く)。
  # レスポンスの階層構造には依存させません (取り出し側で再帰的に探します)。
  if ! jq -e 'type == "object" and (has("error") | not)' "$tmp" >/dev/null 2>&1; then
    usage_log NG '応答が不正' \
      "$(jq -r 'if type=="object" then "keys=" + (keys|join(",")) else type end' "$tmp" 2>/dev/null || printf 'JSON ではない')"
    rm -f "$tmp" 2>/dev/null
    return
  fi
  chmod 600 "$tmp" 2>/dev/null
  if mv -f "$tmp" "$USAGE_CACHE" 2>/dev/null; then
    usage_log OK '' "weekly_scoped $(jq -r "$USAGE_JQ_SCOPED | length" "$USAGE_CACHE" 2>/dev/null) 件"
  else
    rm -f "$tmp" 2>/dev/null
    usage_log NG '書き込み失敗'
  fi
}

# キャッシュが古ければバックグラウンドで更新を投げます。statusline の描画は待たせません
# (古い値を即座に表示し、次の描画で新しい値に入れ替わります)。
maybe_refresh_usage() {
  # キャッシュがまだ新しければ何もしません
  [ "$(file_age "$USAGE_CACHE")" -lt "$USAGE_TTL" ] && return
  mkdir -p "$USAGE_CACHE_DIR" 2>/dev/null || return
  chmod 700 "$USAGE_CACHE_DIR" 2>/dev/null
  # mkdir はアトミックなので、これ 1 つで「複数セッション並走時の同時 curl 防止」と
  # 「失敗が続いても叩き直さないための試行間隔の絞り」を兼ねます。statusline は 1 秒に
  # 何度も呼ばれるため、後者が無いと取得できない状況で毎回 curl が飛びます。
  # 完了時に消さず TTL 経過後に奪う方式にするのが要点で、こうすると判定とマーカー作成の
  # 間に別プロセスが割り込む余地が原理的に無くなります (完了時刻を基準にすると、
  # 判定を通った直後に他が完了してマーカーを書く隙間があり、二重に走ります)。
  if ! mkdir "$USAGE_ATTEMPT" 2>/dev/null; then
    [ "$(file_age "$USAGE_ATTEMPT")" -lt "$USAGE_TTL" ] && return
    rmdir "$USAGE_ATTEMPT" 2>/dev/null
    mkdir "$USAGE_ATTEMPT" 2>/dev/null || return
  fi
  ( trap '' HUP; refresh_usage_cache ) >/dev/null 2>&1 &
}

# モデル別の週次枠を 1 モデル 1 行で出力します。statusline.sh の末尾から呼ばれます。
# 取得できていなければ何も出力しないので、呼び出し側の行数は増えません。
print_model_limits() {
  local state="" reason="" scoped="" err name pct reset p remain r label

  # 取得はバックグラウンドに投げるだけで、ここでは待ちません
  maybe_refresh_usage

  # 直近の取得結果を読みます (形式は usage_log を参照)。
  # 失敗していた場合は古い値を出さず「取得できなかった」ことを画面に出します。
  # 週次枠は数分の遅れなら実用上問題ありませんが、取得が壊れ続けたときに何日も前の値を
  # 最新のものとして見せてしまうと、枠の残りを誤認して判断を誤るためです。
  if [ -r "$USAGE_STATUS" ]; then
    IFS=$'\t' read -r _ state reason _ < "$USAGE_STATUS"
  fi

  # 取得失敗時もモデル名を得るためにキャッシュは読みます (前回取得できていれば名前は分かる)
  if [ -f "$USAGE_CACHE" ]; then
    # kind == "weekly_scoped" を全部拾います。モデル名で絞らないので、新しいモデルが増えても
    # このスクリプトの修正は不要です (本体の /usage はリモート feature gate
    # tengu_usage_overage_included_models のリストで絞っているため、gate 未配信のモデルは
    # /usage には出ずここにだけ出ます)。
    # percent は 0-100 スケール。resets_at は実測では小数秒 + タイムゾーンオフセット付きの
    # ISO 8601 文字列 (YYYY-MM-DDTHH:MM:SS.ffffff+00:00 形式) で届きます。jq の fromdateiso8601 は
    # 末尾 Z の秒精度しか受け付けないため、小数秒を落としオフセットを Z に直してから変換します
    # (API は UTC を返します)。epoch 秒の数値で届いた場合にもそのまま対応します。
    scoped=$(jq -r "$USAGE_JQ_SCOPED"'
      | .[]
      | [ .scope.model.display_name,
          (.percent // 0),
          ( .resets_at
            | if type == "number" then floor
              else ( tostring
                     | sub("\\.[0-9]+"; "")
                     | sub("[+-][0-9]{2}:[0-9]{2}$"; "Z")
                     | fromdateiso8601? // 0 )
              end ) ]
      | @tsv
    ' "$USAGE_CACHE" 2>/dev/null)
  fi

  if [ "$state" = "NG" ]; then
    # 取得に失敗しています。古い値は出さず、既存の 5h/7d が未取得のときと同じ [--%] の
    # プレースホルダーに理由を添えて出します。前回取得できていればモデル名が分かるので
    # その行数だけ、一度も取得できていなければ名前が不明なので 1 行だけ出します。
    err="${YELLOW}取得失敗${RESET}"
    [ -n "$reason" ] && err="${err} ${DIM}(${reason})${RESET}"
    if [ -n "$scoped" ]; then
      while IFS=$'\t' read -r name _; do
        [ -z "$name" ] && continue
        label=$(printf '%-8s' "${name}:")
        printf '%b\n' "${DIM}${label}${RESET} $(bar 15 0 "$DIM") ${DIM}[--%]${RESET} ${err}"
      done <<< "$scoped"
    else
      printf '%b\n' "${DIM}$(printf '%-8s' 'Usage:')${RESET} $(bar 15 0 "$DIM") ${DIM}[--%]${RESET} ${err}"
    fi
  elif [ -n "$scoped" ]; then
    while IFS=$'\t' read -r name pct reset; do
      [ -z "$name" ] && continue
      p=$(printf '%.0f' "$pct" 2>/dev/null)
      case "$p" in (''|*[!0-9]*) p=0;; esac
      case "$reset" in (''|*[!0-9]*) reset=0;; esac
      remain=""
      if [ "$reset" -gt 0 ]; then
        r=$(fmt_remain "$reset")
        [ -n "$r" ] && remain=" ${DIM}${r}${RESET}"
      fi
      label=$(printf '%-8s' "${name}:")
      printf '%b\n' "${DIM}${label}${RESET} $(bar 15 "$p" "$(color_for_pct "$p")") ${DIM}[${p}%]${RESET}${remain}"
    done <<< "$scoped"
  fi
}
