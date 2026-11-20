param(
  [Parameter(Mandatory)][string]$GraphPath,
  [Parameter(Mandatory)][string]$LinkNode,
  [Parameter(Mandatory)][string]$ProfileNode,
  [switch]$Destroy
)
$ErrorActionPreference = 'Stop'
$edges = @{}
foreach ($line in Get-Content -LiteralPath $GraphPath) {
  if ($line -match '^\s*"(?<from>(?:\\.|[^"])*)"\s*->\s*"(?<to>(?:\\.|[^"])*)"') {
    $from = $Matches.from.Replace('\"', '"')
    $to = $Matches.to.Replace('\"', '"')
    if (!$edges.ContainsKey($from)) { $edges[$from] = @() }
    $edges[$from] += $to
  }
}
if (!$edges.Count) { throw 'No Terraform DOT dependency edges found.' }
$start, $end = if ($Destroy) { $ProfileNode, $LinkNode } else { $LinkNode, $ProfileNode }
$pending = [Collections.Generic.Stack[string]]::new()
$seen = [Collections.Generic.HashSet[string]]::new()
$pending.Push($start)
$found = $false
while ($pending.Count) {
  $node = $pending.Pop()
  if (!$seen.Add($node)) { continue }
  if ($node -eq $end) { $found = $true; break }
  foreach ($dependency in $edges[$node]) { $pending.Push($dependency) }
}
if (!$found) { throw "Missing lifecycle dependency: $start -> $end" }
"PASS lifecycle dependency: $start -> $end"
