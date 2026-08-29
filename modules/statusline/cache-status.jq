.prompt_cache as $c |
if ($c.caching_observed // false) == false then ""
else
  if ($c.warm // false) then
    ((($c.expires_at // 0) - (now | floor)) | if . < 0 then 0 else . end) as $s |
    "🔥" + ($c.ttl // "?")
    + " \(($s / 60) | floor):\("0" + (($s % 60) | tostring) | .[-2:])"
    + (if $c.hit_ratio != null then " ·\(($c.hit_ratio * 100) | round)%" else "" end)
  else
    "❄ cold"
    + (if ($c.recache_tokens_if_cold // 0) > 0
       then " ~\(($c.recache_tokens_if_cold / 1000) | round)k re-cache"
       else "" end)
  end
end
