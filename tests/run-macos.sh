#!/usr/bin/env bash
set -u
export PYTHONDONTWRITEBYTECODE=1
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root" || exit 1

status=0
printf 'macOS validation\n'
printf 'bash: %s\n' "${BASH_VERSION}"
printf 'zsh: %s\n' "$(zsh --version 2>/dev/null || printf unavailable)"
printf 'python: %s\n' "$(python3 --version 2>&1 || printf unavailable)"

bats_bin=${BATS_BIN:-$(command -v bats 2>/dev/null || true)}
if [[ -z "$bats_bin" ]]; then
  printf 'UNAVAILABLE: bats-core is required for shell suites.\n' >&2
  status=1
else
  "$bats_bin" tests/zsh/maintenance/maintenance.bats \
    tests/zsh/dev-tools/codex-project-profiles/test_codex_project_profiles.bats \
    tests/zsh/system-maintenance/test_system_maintenance.bats || status=1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck zsh/macos_maintenance.sh snippets/zsh/macos_maintenance.sh || status=1
else
  printf 'UNAVAILABLE: shellcheck is required.\n' >&2
  status=1
fi

bash -n zsh/macos_maintenance.sh snippets/zsh/macos_maintenance.sh || status=1
zsh -n modules/zsh/dev-tools/codex-project-profiles/codex-project-profiles.plugin.zsh || status=1

if command -v uv >/dev/null 2>&1; then
  validation_dir=$(mktemp -d)
  trap 'rm -rf "$validation_dir"' EXIT
  for package in data-science dev-tools document-tools; do
    cp -R "./modules/python/$package" "$validation_dir/source-$package"
    uv venv "$validation_dir/$package" >/dev/null || { status=1; continue; }
    uv pip install --python "$validation_dir/$package/bin/python" "$validation_dir/source-${package}[test]" >/dev/null || { status=1; continue; }
    "$validation_dir/$package/bin/python" -m pytest "tests/python/$package" || status=1
    "$validation_dir/$package/bin/$package" --help >/dev/null || status=1
    "$validation_dir/$package/bin/$package" example >/dev/null || status=1
    "$validation_dir/$package/bin/$package" example --option >/dev/null || status=1
  done
else
  printf 'UNAVAILABLE: uv is required for isolated Python installation checks.\n' >&2
  status=1
fi

exit "$status"
