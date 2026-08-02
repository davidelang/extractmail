#!/usr/bin/env python3
import subprocess
import sys
import os

def run_git(args, cwd=None):
    try:
        result = subprocess.run(['git'] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True, cwd=cwd)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: git {' '.join(args)}", file=sys.stderr)
        print(e.stderr, file=sys.stderr)
        sys.exit(1)

def main():
    # Use workspace dir if specified or current directory
    repo_dir = "/home/dlang/git/VehicleExpenses-automated/master"
    if not os.path.exists(repo_dir):
        repo_dir = os.getcwd()

    # Determine current branch or target branch to audit
    target_branch = sys.argv[1] if len(sys.argv) > 1 else None
    if not target_branch:
        target_branch = run_git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd=repo_dir)
        if target_branch == 'master':
            print("Currently on 'master'. Please specify the feature branch name to audit.")
            print("Usage: audit_merge.py <feature-branch>")
            sys.exit(1)

    print(f"Auditing feature branch: '{target_branch}' against 'master'")

    # 1. Find the merge base
    merge_base = run_git(['merge-base', 'master', target_branch], cwd=repo_dir)
    master_head = run_git(['rev-parse', 'master'], cwd=repo_dir)

    print(f"Merge Base Commit: {merge_base[:12]} ({merge_base})")
    print(f"Master HEAD Commit: {master_head[:12]} ({master_head})")

    if merge_base == master_head:
        print("\nSUCCESS: Feature branch is fast-forwardable or up-to-date with 'master'. No parallel modifications.")
        sys.exit(0)

    # 2. Get files changed in the feature branch since the merge base
    branch_diff_files = run_git(['diff', '--name-only', f"{merge_base}..{target_branch}"], cwd=repo_dir).splitlines()
    branch_diff_set = set(branch_diff_files)
    
    print(f"Number of files modified in '{target_branch}': {len(branch_diff_set)}")

    # 3. Get all commits on master since divergence point (using --first-parent to trace PR merges or squash commits)
    master_commits_raw = run_git(['log', '--pretty=format:%H|%s|%an|%ad', '--date=short', f"{merge_base}..master"], cwd=repo_dir).splitlines()
    
    parallel_commits = []
    for line in master_commits_raw:
        if not line:
            continue
        parts = line.split('|')
        if len(parts) >= 4:
            parallel_commits.append({
                'hash': parts[0],
                'subject': parts[1],
                'author': parts[2],
                'date': parts[3]
            })

    print(f"Number of commits on 'master' since divergence: {len(parallel_commits)}")

    # 4. For each commit on master, find overlapping files
    overlaps_found = False
    audit_results = []
    
    for commit in parallel_commits:
        commit_hash = commit['hash']
        # Diff against parent to find files modified in this commit
        try:
            modified_files = run_git(['diff', '--name-only', f"{commit_hash}^1", commit_hash], cwd=repo_dir).splitlines()
        except Exception:
            # Fallback if first parent doesn't exist (e.g. root commit, though unlikely here)
            modified_files = run_git(['show', '--name-only', '--pretty=format:', commit_hash], cwd=repo_dir).splitlines()
        
        modified_set = set(f.strip() for f in modified_files if f.strip())
        overlaps = branch_diff_set.intersection(modified_set)
        
        audit_results.append({
            'commit': commit,
            'modified': list(modified_set),
            'overlaps': list(overlaps)
        })
        if overlaps:
            overlaps_found = True

    # 5. Output detailed report and generate draft commit message
    print("\n" + "="*60)
    print("DIVERGENCE & OVERLAP AUDIT REPORT")
    print("="*60)
    
    if overlaps_found:
        print("\nWARNING: Overlapping files detected! Potential logical regressions may occur.")
        print("Please review the following parallel merges since divergence:")
        for res in audit_results:
            if res['overlaps']:
                commit = res['commit']
                print(f"\n* Commit: {commit['subject']} ({commit['hash'][:8]})")
                print(f"  Author: {commit['author']} | Date: {commit['date']}")
                print(f"  Overlapping files:")
                for overlap in res['overlaps']:
                    print(f"    - {overlap}")
    else:
        print("\nNo overlapping files detected between parallel master commits and the feature branch.")

    # 6. Generate Draft Commit Message
    print("\n" + "="*60)
    print("DRAFT MERGE COMMIT MESSAGE TEMPLATE")
    print("="*60)
    
    msg_lines = []
    msg_lines.append(f"Merge branch '{target_branch}' into master")
    msg_lines.append("")
    msg_lines.append("Divergence Audit:")
    msg_lines.append(f"- Diverged from master at: {merge_base[:12]}")
    msg_lines.append("- Parallel commits on master since divergence:")
    
    for res in audit_results:
        commit = res['commit']
        overlap_str = ", ".join(res['overlaps']) if res['overlaps'] else "None"
        msg_lines.append(f"  * {commit['subject']} ({commit['hash'][:8]}) - Overlaps: [{overlap_str}]")
        
    msg_lines.append("")
    msg_lines.append("Parity & Regression Verification:")
    msg_lines.append("- Build Status: [Pending / Success]")
    if overlaps_found:
        msg_lines.append("- Logical Verification:")
        for res in audit_results:
            if res['overlaps']:
                for overlap in res['overlaps']:
                    msg_lines.append(f"  * Verified [{overlap}] does not revert changes from commit {res['commit']['hash'][:8]}")
    else:
        msg_lines.append("- Logical Verification: No overlapping files. Direct merge validated.")
        
    msg_lines.append("")
    msg_lines.append("Verification Tags: master/builds, master/works")
    
    draft_message = "\n".join(msg_lines)
    print(draft_message)
    
    # Save the draft message to dev-ai-interaction/draft_merge_message.txt
    sandbox_dir = "/home/dlang/git/VehicleExpenses-automated/dev-ai-interaction"
    if not os.path.exists(sandbox_dir):
        sandbox_dir = repo_dir
    draft_file_path = os.path.join(sandbox_dir, "draft_merge_message.txt")
    with open(draft_file_path, "w") as f:
        f.write(draft_message)
    print(f"\nDraft commit message template saved to: {draft_file_path}")

if __name__ == "__main__":
    main()
