#!/usr/bin/env bash
# Single owner of a ship task's mode-specific "Definition of done" block.
# Sourced by bin/fm-brief.sh, which renders it into a generated ship brief, and by
# bin/fm-promote.sh, which renders it into the ship instructions a promoted scout
# receives. Both paths must hand the worker the same contract: a promoted
# no-mistakes worker that never received the ask-user escalation rule or the
# `--yes` ban is the exact delivery hole this single owner exists to close.
# fm_dod_block <no-mistakes|direct-PR|local-only> <task-id> <data-dir> prints the
# block on stdout with no trailing blank line. The caller validates the mode; an
# unknown mode is refused rather than silently rendered as the pipeline contract.
# <data-dir> is the firstmate home's data directory. It is required for every
# mode so a caller cannot forget it on the one mode that reads it, and it is
# resolved to its physical path here rather than by each caller, so the brief
# scaffold and a scout promotion render byte-identical blocks even when their
# own FM_HOME resolution differs (tests/fm-task-delivery.test.sh compares them).
# Only the no-mistakes block uses it, for the record the review cap writes to.
# That cap is part of this contract because the pipeline's review loop is what
# it bounds: a run that parks repeatedly on info-severity wording, naming, or
# duplication findings costs a firstmate decision turn each time and changes
# nothing an owner would see. Recording those findings instead of fixing them
# keeps them from being silently dropped, and the record lives in the firstmate
# home rather than the worktree so it survives the worktree being discarded.
# The cap governs severity, never authority: it decides what is worth fixing and
# never who answers. An ask-user finding still routes to firstmate at every
# severity, so the block states that boundary out loud rather than leaving a
# worker who reads only the brief to rank the two rules against each other.
# The block opens with the fixed machine-readable "Delivery contract: mode=<mode>"
# line that bin/fm-spawn.sh checks a ship brief against.
# Every heredoc here stays outside a command substitution: `VAR=$(cat <<EOF ...)`
# breaks parsing of the whole file on Bash 3.2 (tests/fm-brief.test.sh).

fm_dod_block() {  # <mode> <task-id> <data-dir>
  local mode=$1 id=$2 data=${3:-} findings
  if [ -z "$data" ]; then
    echo "error: fm_dod_block: the firstmate data directory is required" >&2
    return 1
  fi
  findings=$(CDPATH='' cd -- "$data" 2>/dev/null && pwd -P) || findings=${data%/}
  findings="${findings%/}/$id/remaining-findings.md"
  case "$mode" in
    direct-PR)
      cat <<EOF
# Definition of done
Delivery contract: mode=direct-PR
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch and open a PR with \`gh-axi\`, then append \`done: PR {url}\` to the status file and stop.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.
EOF
      ;;
    local-only)
      cat <<EOF
# Definition of done
Delivery contract: mode=local-only
This task ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch \`fm/$id\`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if \`main\` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append \`done: ready in branch fm/$id\` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local \`main\` through the guarded fast-forward path.
EOF
      ;;
    no-mistakes)
      cat <<EOF
# Definition of done
Delivery contract: mode=no-mistakes
The task is complete only when committed on your branch.
When you believe it is complete, append \`done: {summary}\` to the status file and stop.
Firstmate will then instruct you to run /no-mistakes to validate and ship a PR.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and \`no-mistakes axi run --help\` plus the \`help\` lines in each \`axi\` response are authoritative and version-matched to the installed binary.
When starting no-mistakes, make \`--intent\` preserve all relevant content from this brief's \`# Task\` section plus every later accepted Firstmate requirement, clarification, constraint, exclusion, and supersession, carrying only each requirement's current accepted form; retain direct requirements instead of substituting a diff summary, and exclude generic operational, status, delivery, and other scaffold boilerplate unless it is task-specific.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are never yours to answer: escalate to firstmate (rule 6) and stop.
  Firstmate applies \`ask-user-authority\` and obtains any required captain decision.
  When the decision comes back, feed it to the gate with \`no-mistakes axi respond\` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- NEVER pass \`--yes\` (or \`-y\`) to \`no-mistakes axi run\` or \`no-mistakes axi respond\`. It is banned fleet-wide.
  It auto-resolves every gate including ask-user findings with no escalation, and answering your own ask-user finding is a hard rule violation.

Cap the review loop. Fix genuine defects the review finds, and do not let cosmetic ones park the run:
- The cap decides what is worth fixing; it never decides who answers. A finding the pipeline classifies as \`ask-user\` is never yours to approve, fix, or skip, at any severity - route it to firstmate exactly as the rule above requires and apply only the decision that comes back. Every bullet below applies only to findings that are already yours to decide.
- At \`info\` severity, approve the finding unfixed and record it verbatim in \`$findings\` instead. Do not fix it, do not polish it, and do not stop to ask about it. Writing that one record is an authorized exception to the rule keeping you inside the worktree; it lives outside the worktree so it survives after the worktree is discarded.
- Stop with \`needs-decision\` only for a genuine correctness or security defect. Producing a wrong result, losing data, corrupting a record, and exposing it are examples of that, not the whole of it. Wording, naming, structure, duplication, and documentation never qualify, whatever severity they carry.
- Take on no new refactors, no scope broadening, and no tidiness work.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), append \`done: PR {url} checks green\` and stop. You are finished.
EOF
      ;;
    *)
      echo "error: fm_dod_block: unknown delivery mode '$mode'" >&2
      return 1 ;;
  esac
}
