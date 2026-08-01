function ConvertTo-UeefTaskSignalText([Parameter(Mandatory)][string]$Task) {
  $text = $Task.ToLowerInvariant()
  $signals = [Collections.Generic.List[string]]::new()
  $rules = @(
    @{ Pattern='\u0627\u0634\u0631\u062d|\u0641\u0633\u0631|\u0644\u062e\u0635|\u062a\u0631\u062c\u0645|\u0645\u0627 \u0647\u0648|\u0627\u064a\u0647 \u0647\u0648'; Signal='explain summarize translate' },
    @{ Pattern='[\u0627\u0623]\u0635\u0644\u062d|\u0639\u062f\u0644|\u063a\u064a\u0631|\u062d\u062f\u062b|\u062d\u0633\u0646|\u0637\u0648\u0631'; Signal='fix update change improve' },
    @{ Pattern='\u0646\u0641\u0630|\u0637\u0628\u0642'; Signal='implement' },
    @{ Pattern='[\u0627\u0623]\u0636\u0641|\u0636\u064a\u0641'; Signal='add' },
    @{ Pattern='[\u0627\u0623]\u062d\u0630\u0641|[\u0627\u0623]\u0645\u0633\u062d'; Signal='remove delete' },
    @{ Pattern='\u062b\u0628\u062a'; Signal='install' },
    @{ Pattern='[\u0627\u0623]\u0639\u0645\u0644|[\u0627\u0623]\u0628\u0646\u064a|[\u0627\u0623]\u0646\u0634\u0626'; Signal='build create new' },
    @{ Pattern='[\u0627\u0623]\u0641\u062d\u0635|\u0631\u0627\u062c\u0639|\u062f\u0642\u0642|\u062d\u0644\u0644|[\u0627\u0623]\u062e\u062a\u0628\u0631|\u062a[\u0627\u0623]\u0643\u062f|\u0627\u062a[\u0627\u0623]\u0643\u062f|\u0634\u0648\u0641|\u0634\u062e\u0635'; Signal='audit review inspect verify diagnose test' },
    @{ Pattern='\u0643\u0644 \u062d\u0627\u062c[\u0629\u0647]|\u0643\u0644 \u0634\u064a[\u0621\u0626]|\u0628\u0627\u0644\u0643\u0627\u0645\u0644|\u0634\u0627\u0645\u0644|\u062d\u0631\u0641\u064a[\u0627\u064b]|\u0645\u0646 \u0627\u0644[\u0627\u0623]\u0648\u0644 \u0644\u0644[\u0627\u0622]\u062e\u0631'; Signal='system-wide entire project all issues' },
    @{ Pattern='\u0648\u0627\u062c\u0647[\u0629\u0647] \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645|\u0627\u0644\u0648\u0627\u062c\u0647[\u0629\u0647]|\u0641\u0631\u0648\u0646\u062a|\u0641\u0648\u0631\u0646\u062a|\u0635\u0641\u062d[\u0629\u0647]|\u0634\u0627\u0634[\u0629\u0647]|\u0645\u0643\u0648\u0646'; Signal='ui frontend page screen component' },
    @{ Pattern='(?:\u0627\u0644)?\u0642\u0627\u0626\u0645[\u0629\u0647] (?:\u0627\u0644)?\u0645\u0646\u0633\u062f\u0644[\u0629\u0647]'; Signal='dropdown' },
    @{ Pattern='\u062c\u062f\u0648\u0644'; Signal='table' },
    @{ Pattern='\u062a\u0635\u0645\u064a\u0645'; Signal='design' },
    @{ Pattern='[\u0627\u0623]\u0644\u0648\u0627\u0646'; Signal='palette' },
    @{ Pattern='\u0645\u062a\u0635\u0641\u062d|\u0643\u0631\u0648\u0645|\u062a\u0628\u0648\u064a\u0628|\u0645\u0648\u0642\u0639|\u0644\u0642\u0637[\u0629\u0647] \u0634\u0627\u0634[\u0629\u0647]'; Signal='browser chrome tab website screenshot' },
    @{ Pattern='[\u0627\u0623]\u062d\u062f\u062b|\u062d\u0627\u0644\u064a|\u0627\u0644[\u0627\u0622]\u0646|\u062c\u062f\u064a\u062f'; Signal='latest current newest' },
    @{ Pattern='\u062a\u0648\u062b\u064a\u0642|\u0648\u062b\u0627\u0626\u0642|\u062a\u0639\u0644\u064a\u0645\u0627\u062a'; Signal='documentation docs' },
    @{ Pattern='\u0645\u0634\u0643\u0644[\u0629\u0647]|\u062e\u0637[\u0623\u0627]|\u0639\u0637\u0644|\u0645\u0643\u0633\u0648\u0631|\u0645\u062e\u062a\u0644|\u0628\u0637[\u0621\u064a]|\u0643\u0641\u0627[\u0621\u0626][\u0629\u0647]|\u0641\u0634\u0644|\u0628\u064a\u0643\u0631\u0631'; Signal='bug broken error slow performance failure debugging' },
    @{ Pattern='[\u0627\u0623]\u0645\u0627\u0646|[\u0627\u0623]\u0645\u0646|\u062d\u0645\u0627\u064a[\u0629\u0647]|\u062b\u063a\u0631[\u0629\u0647]'; Signal='security vulnerability' },
    @{ Pattern='\u0635\u0644\u0627\u062d\u064a\u0627\u062a'; Signal='authorization permission access control' },
    @{ Pattern='\u062a\u0633\u062c\u064a\u0644 \u062f\u062e\u0648\u0644'; Signal='authentication login identity' },
    @{ Pattern='\u062d\u0630\u0641 \u0646\u0647\u0627\u0626\u064a|\u0628\u062f\u0648\u0646 \u0631\u062c\u0639[\u0629\u0647]|\u0641\u0642\u062f \u0628\u064a\u0627\u0646\u0627\u062a'; Signal='destructive delete permanently data loss' },
    @{ Pattern='[\u0627\u0625]\u0646\u062a\u0627\u062c|\u0628\u0631\u0648\u062f\u0643\u0634\u0646|\u0628\u064a\u0626[\u0629\u0647] \u0645\u0628\u0627\u0634\u0631[\u0629\u0647]'; Signal='production live environment' },
    @{ Pattern='\u062a\u0631\u062d\u064a\u0644'; Signal='migration migrate schema change' },
    @{ Pattern='\u062e\u0635\u0648\u0635\u064a[\u0629\u0647]|\u0628\u064a\u0627\u0646\u0627\u062a \u0634\u062e\u0635\u064a[\u0629\u0647]'; Signal='privacy personal data' },
    @{ Pattern='\u062f\u0641\u0639|\u0645\u062f\u0641\u0648\u0639\u0627\u062a|\u0641\u0648\u062a\u0631[\u0629\u0647]'; Signal='payment billing' },
    @{ Pattern='\u0627\u062e\u062a\u0631\u0627\u0642|\u062a\u0648\u0642\u0641 \u0634\u0627\u0645\u0644|\u062d\u0627\u062f\u062b'; Signal='incident outage breach' },
    @{ Pattern='\u0631\u064a\u0644\u064a\u0632|[\u0627\u0625]\u0635\u062f\u0627\u0631|\u0646\u0634\u0631|[\u0627\u0623]\u0631\u0641\u0639|\u062c\u064a\u062a \u0647\u0628'; Signal='release publish deploy github' }
  )
  foreach ($rule in $rules) {
    if ($text -match [regex]::Unescape([string]$rule.Pattern)) { $signals.Add([string]$rule.Signal) }
  }
  if (!$signals.Count) { return $text }
  return "$text $($signals -join ' ')"
}
