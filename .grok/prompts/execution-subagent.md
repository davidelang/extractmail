# Execution obligations (library coder / execute subagent)

1. First action: `./append-to-engineering-log` with dated header.  
2. Re-read approved plan + standard-plan-compliance-block. Status APPROVED.  
3. Each phase: edits only in contract → forensic read → git add → **successful verify** (compile/typecheck + tests; both failure modes = strike).  
4. Baseball: 3 strikes = out (reset last good builds tag); 3 outs = inning-end report in sandbox/implementation-failure-logs/ then stop for replan.  
5. Completeness before handoff.  
6. CODE LANDED + exact END marker. No git push. No works tag.  
7. Stop after handoff.
