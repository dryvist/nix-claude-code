def epoch:
  if . == null then null
  elif type == "number" then .
  elif type == "string" then (fromdateiso8601? // null)
  else null end;

def countdown:
  epoch as $t
  | if $t == null then ""
    else (($t - (now | floor)) | if . < 0 then 0 else . end) as $s
      | if $s >= 86400 then " \(($s / 86400) | floor)d\((($s % 86400) / 3600) | floor)h"
        elif $s >= 3600 then " \(($s / 3600) | floor)h\((($s % 3600) / 60) | floor)m"
        else " \(($s / 60) | floor)m"
        end
    end;

# A window is either the published shape (used_percentage + epoch resets_at)
# or the header-seeded shape (utilization already scaled + ISO resets_at).
def pct:
  if . == null then null
  elif .used_percentage != null then .used_percentage
  elif .utilization != null then .utilization
  else null end;

def window(tag):
  if . == null then ""
  else pct as $p
    | if $p == null then "" else "\(tag) \($p | round)%" + (.resets_at | countdown) end
  end;

(.rate_limits // {}) as $r |
(($r.utilization // $r)) as $b |
[($b.five_hour | window("5h")), ($b.seven_day | window("7d"))]
| map(select(. != ""))
| join("  ")
