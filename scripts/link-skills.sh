#!/bin/sh
#
# Link the skills in this repository into the Claude Code skills directory.
#
# Works on macOS, Linux, WSL, and Git Bash. For native Windows PowerShell use
# scripts/link-skills.ps1 instead.
#
# Usage:
#   scripts/link-skills.sh [link|unlink|status] [skill...] [options]
#
# See --help for the full option list.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
skills_src="$repo_root/skills"

if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    target_dir="$CLAUDE_CONFIG_DIR/skills"
else
    target_dir="${HOME:-}/.claude/skills"
fi

command=link
dry_run=0
force=0
selected=""
failures=0

if [ -t 1 ]; then
    c_ok=$(printf '\033[32m'); c_warn=$(printf '\033[33m')
    c_err=$(printf '\033[31m'); c_dim=$(printf '\033[2m'); c_off=$(printf '\033[0m')
else
    c_ok=''; c_warn=''; c_err=''; c_dim=''; c_off=''
fi

usage() {
    cat <<'USAGE'
Link this repository's skills into the Claude Code skills directory.

Usage:
  link-skills.sh [command] [skill...] [options]

Commands:
  link            Create a symlink for each skill (default)
  unlink          Remove symlinks that point into this repository
  status          Report the state of each skill without changing anything

Arguments:
  skill...        Skill names to act on. Default: every skill in skills/.

Options:
  -t, --target DIR   Skills directory to link into.
                     Default: $CLAUDE_CONFIG_DIR/skills, else ~/.claude/skills
  -n, --dry-run      Print what would happen, change nothing
  -f, --force        Replace symlinks that point somewhere else.
                     Never removes real files or directories.
  -h, --help         Show this help

Examples:
  link-skills.sh                     # link every skill
  link-skills.sh link brainstorm     # link one skill
  link-skills.sh status
  link-skills.sh unlink --dry-run
USAGE
}

# Physical path a symlink resolves to, or the raw link text if it is broken.
resolve_link() {
    if resolved=$(CDPATH= cd -P -- "$1" 2>/dev/null && pwd -P); then
        printf '%s\n' "$resolved"
    else
        readlink -- "$1" 2>/dev/null || printf '%s\n' '<unreadable>'
    fi
}

report() { printf '%s%s%s %-16s %s\n' "$2" "$1" "$c_off" "$3" "$4"; }
ok()   { report ' ok ' "$c_ok"   "$1" "$2"; }
warn() { report 'skip' "$c_warn" "$1" "$2"; }
fail() { report 'fail' "$c_err"  "$1" "$2"; failures=$((failures + 1)); }

run() {
    [ "$dry_run" -eq 1 ] || "$@"
}

# Reports "linked" when acting for real, "would link" during a dry run.
said() {
    if [ "$dry_run" -eq 1 ]; then printf 'would %s' "$1"; else printf '%s' "$2"; fi
}

# Every skill directory in the repository, one name per line.
all_skills() {
    for dir in "$skills_src"/*/; do
        [ -f "$dir/SKILL.md" ] || continue
        basename "${dir%/}"
    done
}

link_one() {
    name=$1
    src="$skills_src/$name"
    dst="$target_dir/$name"

    if [ ! -f "$src/SKILL.md" ]; then
        fail "$name" "no skills/$name/SKILL.md in this repository"
        return
    fi

    if [ -L "$dst" ]; then
        current=$(resolve_link "$dst")
        if [ "$current" = "$src" ]; then
            ok "$name" "already linked"
            return
        fi
        if [ "$force" -eq 0 ]; then
            warn "$name" "link points to $current — rerun with --force to replace"
            return
        fi
        run rm -f -- "$dst"
    elif [ -e "$dst" ]; then
        fail "$name" "$dst is a real file or directory — move it aside first"
        return
    fi

    run ln -s -- "$src" "$dst"
    ok "$name" "$(said link linked) -> $src"
}

unlink_one() {
    name=$1
    src="$skills_src/$name"
    dst="$target_dir/$name"

    if [ -L "$dst" ]; then
        current=$(resolve_link "$dst")
        case "$current" in
            "$src"|"$skills_src"/*)
                run rm -f -- "$dst"
                ok "$name" "$(said unlink unlinked)"
                ;;
            *)
                warn "$name" "link points outside this repository ($current) — left alone"
                ;;
        esac
    elif [ -e "$dst" ]; then
        warn "$name" "$dst is a real file or directory — left alone"
    else
        ok "$name" "not linked"
    fi
}

status_one() {
    name=$1
    src="$skills_src/$name"
    dst="$target_dir/$name"

    if [ -L "$dst" ]; then
        current=$(resolve_link "$dst")
        if [ "$current" = "$src" ]; then
            ok "$name" "linked"
        else
            warn "$name" "linked to $current"
        fi
    elif [ -e "$dst" ]; then
        warn "$name" "$dst exists and is not a symlink"
    else
        warn "$name" "not linked"
    fi
}

# Links in the target directory that point into this repository but no longer
# have a source — left behind by a renamed or deleted skill.
report_stale() {
    [ -d "$target_dir" ] || return 0
    for entry in "$target_dir"/*; do
        [ -L "$entry" ] || continue
        name=$(basename -- "$entry")
        [ -d "$skills_src/$name" ] && continue
        current=$(resolve_link "$entry")
        case "$current" in
            "$skills_src"/*) warn "$name" "stale link into this repository — run: unlink $name" ;;
        esac
    done
}

while [ $# -gt 0 ]; do
    case "$1" in
        link|unlink|status) command=$1 ;;
        -n|--dry-run)       dry_run=1 ;;
        -f|--force)         force=1 ;;
        -t|--target)
            [ $# -ge 2 ] || { printf 'error: --target needs a directory\n' >&2; exit 2; }
            target_dir=$2; shift ;;
        --target=*)         target_dir=${1#--target=} ;;
        -h|--help)          usage; exit 0 ;;
        -*)                 printf 'error: unknown option %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)                  selected="$selected $1" ;;
    esac
    shift
done

[ -d "$skills_src" ] || { printf 'error: no skills/ directory in %s\n' "$repo_root" >&2; exit 1; }

skills=${selected:-$(all_skills)}
[ -n "$skills" ] || { printf 'error: no skills found in %s\n' "$skills_src" >&2; exit 1; }

printf '%srepo:  %s%s\n' "$c_dim" "$repo_root" "$c_off"
printf '%sinto:  %s%s\n' "$c_dim" "$target_dir" "$c_off"
[ "$dry_run" -eq 1 ] && printf '%smode:  dry run, nothing is written%s\n' "$c_dim" "$c_off"
printf '\n'

if [ "$command" = link ] && [ ! -d "$target_dir" ]; then
    run mkdir -p -- "$target_dir"
fi

for name in $skills; do
    case "$command" in
        link)   link_one   "$name" ;;
        unlink) unlink_one "$name" ;;
        status) status_one "$name" ;;
    esac
done

[ "$command" = status ] && report_stale

printf '\n'
if [ "$failures" -gt 0 ]; then
    printf '%s%d skill(s) need attention.%s\n' "$c_err" "$failures" "$c_off"
    exit 1
fi
if [ "$command" != status ] && [ "$dry_run" -eq 0 ]; then
    printf '%sDone. Start a new Claude Code session to pick up the changes.%s\n' "$c_dim" "$c_off"
fi
