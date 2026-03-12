#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║              OpenClaw / MoltBot 管理脚本                        ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  作者     GitHub  : by Joey                                     ║
# ║           YouTube : @joeyblog                                   ║
# ║           Telegram: https://t.me/+ft-zI76oovgwNmRh             ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  致谢 / 引用                                                    ║
# ║  · 原始脚本基础来自 kejilion（@kejilion）                       ║
# ║  · CLIProxyAPI 安装器来自 cliproxyapi-installer                 ║
# ║    github.com/brokechubb/cliproxyapi-installer                  ║
# ╚══════════════════════════════════════════════════════════════════╝
#
: "${gl_hui:='\e[37m'}"
: "${gl_hong:='\033[31m'}"
: "${gl_lv:='\033[32m'}"
: "${gl_huang:='\033[33m'}"
: "${gl_lan:='\033[34m'}"
: "${gl_bai:='\033[0m'}"
: "${gl_zi:='\033[35m'}"
: "${gl_kjlan:='\033[96m'}"

if ! declare -f break_end > /dev/null 2>&1; then
break_end() {
	if command -v gum >/dev/null 2>&1; then
		echo
		gum style --foreground 240 "  ───────────────────────────────────────  "
		gum input --placeholder "» 按回车继续 «" --prompt "  " > /dev/null
	else
		echo "  ─── 按任意键继续 ───"
		read -n 1 -s -r -p ""
		echo
	fi
	clear
}
fi

if ! declare -f install > /dev/null 2>&1; then
install() {
	if [[ $# -eq 0 ]]; then
		echo "未提供软件包参数"
		return 1
	fi
	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			echo -e "${gl_kjlan}正在安装 $package...${gl_bai}"
			if [[ "$(uname -s)" == "Darwin" ]]; then
				_ensure_brew &>/dev/null
				command -v brew &>/dev/null && brew install "$package" &>/dev/null
			elif command -v dnf &>/dev/null; then
				dnf install -y "$package" &>/dev/null
			elif command -v yum &>/dev/null; then
				yum install -y "$package" &>/dev/null
			elif command -v apt &>/dev/null; then
				DEBIAN_FRONTEND=noninteractive apt install -y "$package" &>/dev/null
			elif command -v apk &>/dev/null; then
				apk add "$package" &>/dev/null
			elif command -v pacman &>/dev/null; then
				pacman -S --noconfirm "$package" &>/dev/null
			elif command -v zypper &>/dev/null; then
				zypper install -y "$package" &>/dev/null
			elif command -v opkg &>/dev/null; then
				opkg install "$package" &>/dev/null
			elif command -v pkg &>/dev/null; then
				pkg install -y "$package" &>/dev/null
			else
				echo "未知的包管理器，无法安装 $package"
				return 1
			fi
		fi
	done
}
fi

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

_ensure_brew() {
	if ! command -v brew &>/dev/null; then
		if [[ -f /opt/homebrew/bin/brew ]]; then
			eval "$(/opt/homebrew/bin/brew shellenv)"
		elif [[ -f /usr/local/bin/brew ]]; then
			eval "$(/usr/local/bin/brew shellenv)"
		fi
	fi

	if ! command -v brew &>/dev/null; then
		echo "正在安装 Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [[ -f /opt/homebrew/bin/brew ]]; then
			eval "$(/opt/homebrew/bin/brew shellenv)"
		elif [[ -f /usr/local/bin/brew ]]; then
			eval "$(/usr/local/bin/brew shellenv)"
		fi
	fi

	command -v brew &>/dev/null || { echo "Homebrew 安装失败，请手动安装：https://brew.sh"; return 1; }
}

_sed_i() {
	if is_macos; then
		sed -i '' "$@"
	else
		sed -i "$@"
	fi
}

install_base_deps() {
	if is_macos; then
		_ensure_brew || return 1
		local missing_brew=()
		for cmd in curl git nano jq python3 gpg; do
			command -v "$cmd" &>/dev/null || missing_brew+=("$cmd")
		done
		for i in "${!missing_brew[@]}"; do
			[[ "${missing_brew[$i]}" == "gpg" ]] && missing_brew[$i]="gnupg"
		done
		[[ ${#missing_brew[@]} -eq 0 ]] && return 0
		echo "正在安装缺失依赖：${missing_brew[*]}..."
		brew install "${missing_brew[@]}" &>/dev/null
		return 0
	fi

	local -a dep_map=(
		"curl:curl:curl:curl:curl:curl"
		"git:git:git:git:git:git"
		"nano:nano:nano:nano:nano:nano"
		"jq:jq:jq:jq:jq:jq"
		"python3:python3:python3:python3:python:python3"
		"tar:tar:tar:tar:tar:tar"
		"gpg:gnupg:gnupg2:gnupg:gnupg:gpg2"
	)

	local missing_apt=() missing_dnf=() missing_apk=() missing_pacman=() missing_zypper=()

	for entry in "${dep_map[@]}"; do
		IFS=: read -r cmd pkg_apt pkg_dnf pkg_apk pkg_pacman pkg_zypper <<< "$entry"
		command -v "$cmd" &>/dev/null && continue
		missing_apt+=("$pkg_apt")
		missing_dnf+=("$pkg_dnf")
		missing_apk+=("$pkg_apk")
		missing_pacman+=("$pkg_pacman")
		missing_zypper+=("$pkg_zypper")
	done

	[[ ${#missing_apt[@]} -eq 0 ]] && return 0

	echo "正在安装缺失依赖：${missing_apt[*]}..."

	if command -v apt &>/dev/null; then
		apt update -y &>/dev/null
		DEBIAN_FRONTEND=noninteractive apt install -y "${missing_apt[@]}" &>/dev/null
	elif command -v dnf &>/dev/null; then
		dnf install -y epel-release &>/dev/null || true
		dnf install -y "${missing_dnf[@]}" &>/dev/null
	elif command -v yum &>/dev/null; then
		yum install -y epel-release &>/dev/null || true
		yum install -y "${missing_dnf[@]}" &>/dev/null
	elif command -v apk &>/dev/null; then
		apk update &>/dev/null
		apk add "${missing_apk[@]}" &>/dev/null
	elif command -v pacman &>/dev/null; then
		pacman -Sy --noconfirm --needed "${missing_pacman[@]}" &>/dev/null
	elif command -v zypper &>/dev/null; then
		zypper install -y "${missing_zypper[@]}" &>/dev/null
	fi

	if ! command -v python3 &>/dev/null; then
		local py
		py=$(compgen -c 2>/dev/null | grep -E '^python3\.[0-9]+$' | sort -V | tail -1)
		if [[ -n "$py" ]]; then
			ln -sf "$(command -v "$py")" /usr/local/bin/python3 2>/dev/null || true
		fi
	fi

	if ! command -v python3 &>/dev/null; then
		echo "正在安装 python3..."
		if command -v apt &>/dev/null; then
			DEBIAN_FRONTEND=noninteractive apt install -y python3 &>/dev/null
		elif command -v dnf &>/dev/null; then
			dnf install -y python3 &>/dev/null
		elif command -v yum &>/dev/null; then
			yum install -y python3 &>/dev/null
		elif command -v apk &>/dev/null; then
			apk add python3 &>/dev/null
		elif command -v pacman &>/dev/null; then
			pacman -S --noconfirm python &>/dev/null
		elif command -v zypper &>/dev/null; then
			zypper install -y python3 &>/dev/null
		fi
		hash -r 2>/dev/null || true
	fi
}

_install_gum_binary() {
	local arch
	case "$(uname -m)" in
		x86_64)  arch="amd64" ;;
		aarch64) arch="arm64" ;;
		armv7l)  arch="armv7" ;;
		*) echo "不支持的架构: $(uname -m)"; return 1 ;;
	esac
	local latest
	latest=$(curl -fsSL https://api.github.com/repos/charmbracelet/gum/releases/latest \
		| grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
	[[ -z "$latest" ]] && { echo "获取 gum 版本失败"; return 1; }
	local url="https://github.com/charmbracelet/gum/releases/download/v${latest}/gum_${latest}_linux_${arch}.tar.gz"
	local tmp
	tmp=$(mktemp -d)
	curl -fsSL "$url" -o "$tmp/gum.tar.gz" \
		&& tar -xzf "$tmp/gum.tar.gz" -C "$tmp" \
		&& install -m 755 "$tmp/gum" /usr/local/bin/gum
	rm -rf "$tmp"
	command -v gum >/dev/null 2>&1
}

install_gum() {
	command -v gum >/dev/null 2>&1 && return 0
	echo "正在安装 gum..."
	if command -v brew >/dev/null 2>&1; then
		brew install gum
	elif command -v apt >/dev/null 2>&1; then
		command -v gpg >/dev/null 2>&1 || apt install -y gnupg 2>/dev/null
		mkdir -p /etc/apt/keyrings
		if curl -fsSL https://repo.charm.sh/apt/gpg.key \
			| gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null; then
			echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
				| tee /etc/apt/sources.list.d/charm.list >/dev/null
			apt update -y 2>/dev/null && apt install -y gum 2>/dev/null
		fi
		command -v gum >/dev/null 2>&1 || _install_gum_binary
	elif command -v dnf &>/dev/null; then
		cat > /etc/yum.repos.d/charm.repo <<'REPO'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
REPO
		dnf install -y gum
	elif command -v yum &>/dev/null; then
		cat > /etc/yum.repos.d/charm.repo <<'REPO'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
REPO
		yum install -y gum
	elif command -v apk &>/dev/null; then
		apk add gum 2>/dev/null || _install_gum_binary
	elif command -v pacman &>/dev/null; then
		pacman -S --noconfirm gum 2>/dev/null || _install_gum_binary
	elif command -v zypper &>/dev/null; then
		zypper install -y gum 2>/dev/null || _install_gum_binary
	else
		_install_gum_binary
	fi
	command -v gum >/dev/null 2>&1 || { echo "gum 安装失败，请手动安装: https://github.com/charmbracelet/gum"; return 1; }
}

install_fzf() {
	command -v fzf >/dev/null 2>&1 && return 0
	echo "正在安装 fzf..."
	if command -v brew >/dev/null 2>&1; then
		brew install fzf
	elif command -v apt >/dev/null 2>&1; then
		apt install -y fzf
	elif command -v dnf &>/dev/null; then
		dnf install -y fzf
	elif command -v yum &>/dev/null; then
		yum install -y fzf
	elif command -v apk &>/dev/null; then
		apk add fzf
	elif command -v pacman &>/dev/null; then
		pacman -S --noconfirm fzf
	elif command -v zypper &>/dev/null; then
		zypper install -y fzf
	else
		echo "无法自动安装 fzf，请手动安装: https://github.com/junegunn/fzf"
		return 1
	fi
}

_install_shortcut() {
	local store_dir shortcut_dir shortcut

	store_dir="$HOME/.local/bin"
	mkdir -p "$store_dir"

	local _candidate_dirs=("/opt/homebrew/bin" "/usr/local/bin")
	shortcut_dir=""
	for _d in "${_candidate_dirs[@]}"; do
		if [[ -d "$_d" && -w "$_d" ]]; then
			shortcut_dir="$_d"
			break
		fi
	done

	if [[ -z "$shortcut_dir" ]]; then
		shortcut_dir="$store_dir"
		local rc_file=""
		[[ -f "$HOME/.zshrc" ]]  && rc_file="$HOME/.zshrc"
		[[ -f "$HOME/.bashrc" ]] && rc_file="${rc_file:-$HOME/.bashrc}"
		if [[ -n "$rc_file" ]] && ! grep -q "$store_dir" "$rc_file" 2>/dev/null; then
			printf '\nexport PATH="%s:$PATH"\n' "$store_dir" >> "$rc_file"
		fi
		export PATH="$store_dir:$PATH"
	fi

	shortcut="$shortcut_dir/oc"

	cat > "$shortcut" <<EOF
#!/usr/bin/env bash
curl -fsSL https://raw.githubusercontent.com/byJoey/openclawctl/main/openclaw.sh \\
    -o "$store_dir/openclawctl.sh" 2>/dev/null && chmod +x "$store_dir/openclawctl.sh"
exec bash "$store_dir/openclawctl.sh" "\$@"
EOF
	chmod +x "$shortcut"
}

moltbot_menu() {
	is_macos && _ensure_brew

	_install_shortcut

	install_base_deps
	install_gum || { echo "gum 安装失败，无法继续"; return 1; }
	install_fzf || { echo "fzf 安装失败，无法继续"; return 1; }

	ui_header() {
		gum style \
			--bold --foreground 51 \
			--border double --border-foreground 51 \
			--padding "0 2" "$*"
		echo
	}
	ui_ok()   { gum style --foreground 46  "  ◉  $*"; }
	ui_err()  { gum style --foreground 196 "  ✗  $*"; }
	ui_warn() { gum style --foreground 208 "  ⚡  $*"; }
	ui_info() { gum style --foreground 51  "  ◈  $*"; }
	ui_step() { echo; gum style --bold --foreground 201 "  ▶  $*"; echo; }

	check_openclaw_update() {
		if ! command -v npm >/dev/null 2>&1; then
			return 1
		fi

		local local_version remote_version
		local_version=$(npm list -g openclaw --depth=0 --no-update-notifier 2>/dev/null \
			| grep openclaw | awk '{print $NF}' | sed 's/^.*@//')

		[[ -z "$local_version" ]] && return 1

		remote_version=$(npm view openclaw version --no-update-notifier 2>/dev/null)

		[[ -z "$remote_version" ]] && return 1

		if [[ "$local_version" != "$remote_version" ]]; then
			echo -e "\033[38;5;208m⚡ UPDATE AVAILABLE  $remote_version\033[0m"
		else
			echo -e "\033[90m✦ v$local_version\033[0m"
		fi
	}

	get_install_status() {
		if command -v openclaw >/dev/null 2>&1; then
			echo -e "\033[38;5;46m◉ INSTALLED\033[0m"
		else
			echo -e "\033[90m○ NOT FOUND\033[0m"
		fi
	}

	get_running_status() {
		if pgrep -f "openclaw.*gatewa" >/dev/null 2>&1; then
			echo -e "\033[38;5;46m▶ RUNNING\033[0m"
		else
			echo -e "\033[90m■ STOPPED\033[0m"
		fi
	}

	start_gateway() {
		if is_macos; then
			local plist="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
			openclaw gateway stop >/dev/null 2>&1
			launchctl unload "$plist" >/dev/null 2>&1 || true
			if [[ -f "$plist" ]]; then
				gum spin --spinner pulse --title "正在启动网关..." -- \
					bash -c "launchctl load '$plist' 2>/dev/null; sleep 2"
			else
				gum spin --spinner pulse --title "正在安装并启动网关..." -- \
					bash -c "openclaw gateway install 2>/dev/null; sleep 2"
			fi
		else
			openclaw gateway stop >/dev/null 2>&1
			gum spin --spinner pulse --title "正在启动网关..." -- openclaw gateway start
			sleep 1
		fi
	}

	install_node_and_tools() {
		if command -v node &>/dev/null && command -v npm &>/dev/null; then
			return 0
		fi
		echo "正在安装 Node.js..."
		if is_macos; then
			_ensure_brew || return 1
			brew install node &>/dev/null
		elif command -v dnf &>/dev/null; then
			curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - &>/dev/null
			dnf install -y cmake libatomic nodejs &>/dev/null
		elif command -v apt &>/dev/null; then
			curl -fsSL https://deb.nodesource.com/setup_24.x | bash - &>/dev/null
			DEBIAN_FRONTEND=noninteractive apt install -y build-essential python3 libatomic1 nodejs &>/dev/null
		fi
		hash -r 2>/dev/null || true
	}

	configure_openclaw_session_policy() {
		local config_file="${HOME}/.openclaw/openclaw.json"

		[[ ! -f "$config_file" ]] && return 1
		command -v python3 &>/dev/null || install_base_deps

		python3 - "$config_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

session = obj.setdefault('session', {})
session['dmScope'] = session.get('dmScope', 'per-channel-peer')
session['resetTriggers'] = ['/new', '/reset']
session['reset'] = {
    'mode': 'idle',
    'idleMinutes': 10080
}
session['resetByType'] = {
    'direct': {'mode': 'idle', 'idleMinutes': 10080},
    'thread': {'mode': 'idle', 'idleMinutes': 1440},
    'group': {'mode': 'idle', 'idleMinutes': 120}
}

with open(path, 'w', encoding='utf-8') as f:
    json.dump(obj, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
	}

	sync_openclaw_api_models() {
		local config_file="${HOME}/.openclaw/openclaw.json"

		[[ ! -f "$config_file" ]] && return 0
		command -v python3 &>/dev/null || install_base_deps

		python3 - "$config_file" <<'PY'
import copy
import json
import sys
import time
import urllib.request

path = sys.argv[1]

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('未检测到 API providers，跳过模型同步')
    raise SystemExit(0)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models

SUPPORTED_APIS = {'openai-completions', 'openai-responses', 'openai-chat-completions'}

changed = False
fatal_errors = []
summary = []


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


def prompt_delete_provider(name):
    prompt = f"{name} /models 探测连续失败 3 次。是否删除该 API 供应商及其全部相关模型？[y/N]: "
    try:
        ans = input(prompt).strip().lower()
    except EOFError:
        return False
    return ans in ('y', 'yes')


def rebind_defaults_before_delete(name):
    global changed

    replacement = None

    def get_replacement():
        nonlocal replacement
        if replacement is None:
            candidates = collect_available_refs(exclude_provider=name)
            replacement = candidates[0] if candidates else None
        return replacement

    primary_ref = get_primary_ref(defaults)
    if ref_provider(primary_ref) == name:
        repl = get_replacement()
        if not repl:
            summary.append(f'错误 - {name}: 默认主模型指向该 provider，但无可用替代模型，已中止删除')
            return False
        set_primary_ref(defaults, repl)
        changed = True
        summary.append(f'已切换默认主模型: {primary_ref} -> {repl}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if ref_provider(val) == name:
            repl = get_replacement()
            if not repl:
                summary.append(f'错误 - {name}: {fk} 指向该 provider，但无可用替代模型，已中止删除')
                return False
            defaults[fk] = repl
            changed = True
            summary.append(f'已切换 {fk}: {val} -> {repl}')

    return True


def delete_provider_and_refs(name):
    global changed

    if not rebind_defaults_before_delete(name):
        return False

    removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
    for r in removed_refs:
        defaults_models.pop(r, None)
    if removed_refs:
        changed = True

    if name in providers:
        providers.pop(name, None)
        changed = True

    summary.append(f'已删除 provider {name}，并移除 defaults.models 下 {len(removed_refs)} 个模型引用')
    return True


def fetch_remote_models_with_retry(name, base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            data = json.loads(payload)
            return data, None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


for name, provider in list(providers.items()):
    if not isinstance(provider, dict):
        summary.append(f'跳过 {name}: provider 结构非法')
        continue

    api = provider.get('api', '')
    base_url = provider.get('baseUrl')
    api_key = provider.get('apiKey')
    model_list = provider.get('models', [])

    if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
        summary.append(f'跳过 {name}: 无 baseUrl/apiKey/models')
        continue

    if api not in SUPPORTED_APIS:
        summary.append(f'跳过 {name}: 不支持直接 /models 校验 (api={api})')
        continue

    data, err, attempts = fetch_remote_models_with_retry(name, base_url, api_key, retries=3)
    if err is not None:
        summary.append(f'警告 - {name}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
        if prompt_delete_provider(name):
            deleted = delete_provider_and_refs(name)
            if deleted:
                summary.append(f'{name}: 用户已确认删除该 provider 及全部相关模型引用')
        else:
            summary.append(f'{name}: 用户未确认删除，保留现有 provider 配置')
        continue

    if attempts > 1:
        summary.append(f'{name}: /models 第 {attempts} 次重试后成功')

    if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
        summary.append(f'警告 - 跳过 {name}: /models 返回结构不可识别')
        continue

    remote_ids = []
    for item in data['data']:
        if isinstance(item, dict) and item.get('id'):
            remote_ids.append(str(item['id']))
    remote_set = set(remote_ids)

    if not remote_set:
        fatal_errors.append(f'错误 - {name} 上游 /models 为空，无法为该 provider 提供兜底模型')
        continue

    local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
    local_ids = [str(m['id']) for m in local_models]
    local_set = set(local_ids)

    template = None
    for m in local_models:
        template = copy.deepcopy(m)
        break
    if template is None:
        summary.append(f'警告 - 跳过 {name}: 本地 models 无有效模板模型')
        continue

    removed_ids = [mid for mid in local_ids if mid not in remote_set]
    added_ids = [mid for mid in remote_ids if mid not in local_set]

    kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
    new_models = kept_models[:]

    for mid in added_ids:
        nm = copy.deepcopy(template)
        nm['id'] = mid
        if isinstance(nm.get('name'), str):
            nm['name'] = f'{name} / {mid}'
        new_models.append(nm)

    if not new_models:
        fatal_errors.append(f'错误 - {name} 同步后无可用模型，无法保障默认模型/回退模型兜底')
        continue

    expected_refs = {model_ref(name, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
    local_refs = {model_ref(name, mid) for mid in local_ids}

    first_ref = model_ref(name, str(new_models[0]['id']))

    primary_ref = get_primary_ref(defaults)
    if isinstance(primary_ref, str) and primary_ref in (local_refs - expected_refs):
        set_primary_ref(defaults, first_ref)
        changed = True
        summary.append(f'默认模型已兜底替换: {primary_ref} -> {first_ref}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if isinstance(val, str) and val in (local_refs - expected_refs):
            defaults[fk] = first_ref
            changed = True
            summary.append(f'{fk} 已兜底替换: {val} -> {first_ref}')

    stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/') and r not in expected_refs]
    for r in stale_refs:
        defaults_models.pop(r, None)
        changed = True

    for r in sorted(expected_refs):
        if r not in defaults_models:
            defaults_models[r] = {}
            changed = True

    if removed_ids or added_ids or len(local_models) != len(new_models):
        provider['models'] = new_models
        changed = True

    summary.append(f'{name}: 删除 {len(removed_ids)} 个，新增 {len(added_ids)} 个，当前 {len(new_models)} 个')

if fatal_errors:
    for line in summary:
        print(line)
    for err in fatal_errors:
        print(err)
    print('模型同步失败：存在 provider 同步后无可用模型，已中止写入')
    raise SystemExit(2)

if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')
    for line in summary:
        print(line)
    print('OpenClaw API 模型一致性同步完成')
else:
    for line in summary:
        print(line)
    print('无需同步：配置已与上游 /models 保持一致')
PY
	}

	_install_openclaw_core() {
		install_node_and_tools

		git config --global url."${gh_https_url}github.com/".insteadOf ssh://git@github.com/
		git config --global url."${gh_https_url}github.com/".insteadOf git@github.com:

		if is_macos; then
			gum spin --spinner globe --title "正在安装 OpenClaw..." -- \
				env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest
		else
			gum spin --spinner globe --title "正在安装 OpenClaw..." -- npm install -g openclaw@latest
		fi
		hash -r 2>/dev/null || true
		local npm_prefix
		npm_prefix=$(npm prefix -g 2>/dev/null)
		[[ -n "$npm_prefix" ]] && export PATH="$npm_prefix/bin:$PATH"
		openclaw onboard --install-daemon
		_sed_i 's|"profile": "messaging"|"profile": "full"|g' ~/.openclaw/openclaw.json
		configure_openclaw_session_policy
		start_gateway
	}

	install_moltbot() {
		_install_openclaw_core
		break_end
	}

	_cliproxy_dir() {
		if is_macos; then
			echo "$(brew --prefix 2>/dev/null || echo /usr/local)/etc"
		else
			echo "$HOME/cliproxyapi"
		fi
	}

	_cliproxy_conf() {
		if is_macos; then
			echo "$(_cliproxy_dir)/cliproxyapi.conf"
		else
			echo "$(_cliproxy_dir)/config.yaml"
		fi
	}

	_cliproxy_bin() {
		if is_macos; then
			command -v cliproxyapi 2>/dev/null || echo "cliproxyapi"
		else
			echo "$HOME/cliproxyapi/cli-proxy-api"
		fi
	}

	_cliproxy_running() {
		if is_macos; then
			pgrep -f "cliproxyapi" >/dev/null 2>&1
		else
			pgrep -f "cli-proxy-api" >/dev/null 2>&1
		fi
	}

	_cliproxy_start_service() {
		if is_macos; then
			gum spin --spinner pulse --title "正在启动 CLIProxyAPI..." -- \
				bash -c "brew services start cliproxyapi 2>/dev/null; sleep 2"
		else
			systemctl --user enable cliproxyapi.service >/dev/null 2>&1 || true
			gum spin --spinner pulse --title "正在启动 CLIProxyAPI..." -- \
				bash -c "systemctl --user start cliproxyapi.service 2>/dev/null; sleep 3"
			if ! _cliproxy_running; then
				ui_warn "systemd 启动失败，改用后台直接运行..."
				local cliproxy_dir; cliproxy_dir=$(_cliproxy_dir)
				(cd "$cliproxy_dir" && nohup ./cli-proxy-api > /tmp/cliproxyapi.log 2>&1 &)
				sleep 3
			fi
		fi
		if _cliproxy_running; then
			ui_ok "CLIProxyAPI 已启动"
			return 0
		else
			ui_err "CLIProxyAPI 启动失败，请检查 $(_cliproxy_conf) 后手动启动"
			return 1
		fi
	}

	_cliproxy_stop_service() {
		if is_macos; then
			gum spin --spinner pulse --title "正在停止 CLIProxyAPI..." -- \
				bash -c "brew services stop cliproxyapi 2>/dev/null; sleep 2"
		else
			if systemctl --user is-active --quiet cliproxyapi.service 2>/dev/null; then
				gum spin --spinner pulse --title "正在停止 CLIProxyAPI..." -- \
					bash -c "systemctl --user stop cliproxyapi.service 2>/dev/null; sleep 2"
			fi
		fi
		local _pat; _pat=$(is_macos && echo "cliproxyapi" || echo "cli-proxy-api")
		local pids; pids=$(pgrep -f "$_pat" 2>/dev/null || true)
		if [[ -n "$pids" ]]; then
			echo "$pids" | xargs kill 2>/dev/null || true
			sleep 2
			pids=$(pgrep -f "$_pat" 2>/dev/null || true)
			[[ -n "$pids" ]] && echo "$pids" | xargs kill -9 2>/dev/null || true
		fi
		if ! _cliproxy_running; then
			ui_ok "CLIProxyAPI 已停止"
		else
			ui_err "停止失败，仍有进程残留"
		fi
	}

	_cliproxy_oauth_login() {
		local cliproxy_bin; cliproxy_bin=$(_cliproxy_bin)
		if ! command -v "$cliproxy_bin" &>/dev/null && [[ ! -x "$cliproxy_bin" ]]; then
			ui_err "CLIProxyAPI 未安装：$cliproxy_bin"
			return 1
		fi

		local provider_choice
		provider_choice=$(gum choose --cursor "❯ " \
			--header $'  选择要登录的 AI 提供商\n  ↑↓ 移动 · Enter 确认 · q 取消' \
			"Claude (Anthropic)" \
			"Gemini (Google)" \
			"OpenAI / Codex" \
			"Qwen (通义千问)" \
			"iFlow" \
			"取消") || return 0

		local login_cmd="" login_port=""
		case "$provider_choice" in
			"Claude (Anthropic)")  login_cmd="--claude-login"; login_port="54545" ;;
			"Gemini (Google)")     login_cmd="--login";        login_port="8085"  ;;
			"OpenAI / Codex")      login_cmd="--codex-login";  login_port="1455"  ;;
			"Qwen (通义千问)")      login_cmd="--qwen-login";   login_port=""      ;;
			"iFlow")               login_cmd="--iflow-login";  login_port="11451" ;;
			"取消"|*)              return 0 ;;
		esac

		echo
		local cliproxy_dir; cliproxy_dir=$(_cliproxy_dir)
		if [[ -n "$login_port" ]]; then
			if is_macos; then
				gum style \
					--border double --border-foreground 51 \
					--foreground 51 --bold --padding "0 2" \
					"◈  本地浏览器登录流程"
				echo
				gum style --bold --foreground 240 \
					"  浏览器将自动打开，完成授权后自动返回，请稍候..."
				echo
				"$cliproxy_bin" "$login_cmd"
			else
				gum style \
					--border double --border-foreground 51 \
					--foreground 51 --bold --padding "0 2" \
					"◈  服务器登录流程"
				echo
				gum style --bold --foreground 240 \
					"  1. 脚本后台启动 cli-proxy-api，并打印 OAuth 授权链接" \
					"  2. 在本地浏览器打开该链接，完成账号授权" \
					"  3. 授权后浏览器跳转到 localhost:${login_port}，页面报错属正常" \
					"  4. 复制地址栏完整 URL，粘贴到下方提示符，脚本自动完成握手"
				echo
				gum style --foreground 208 \
					"  ⚡ 无需端口转发 — 回调 URL 里已含 code，直接转发给本机处理"
				echo

				(cd "$cliproxy_dir" && "$cliproxy_bin" "$login_cmd" --no-browser) &
				local cli_pid=$!
				sleep 2

				echo
				local callback_url
				callback_url=$(gum input \
					--placeholder "http://localhost:${login_port}/oauth2callback?code=..." \
					--prompt "  ❯ " \
					--width 120 \
					--char-limit 2000) || true

				if [[ -n "$callback_url" ]]; then
					ui_info "正在向本机发送回调..."
					curl -sf "$callback_url" > /dev/null 2>&1 || true
					sleep 1
				fi
				wait "$cli_pid" 2>/dev/null || true
			fi
		else
			ui_info "Qwen 使用 device flow，无需粘贴回调"
			echo
			gum style --foreground 240 "将打印授权码 + URL，在任意浏览器中打开并输入授权码即可"
			echo
			if is_macos; then
				"$cliproxy_bin" "$login_cmd"
			else
				(cd "$cliproxy_dir" && "$cliproxy_bin" "$login_cmd" --no-browser)
			fi
		fi
	}

	cliproxyapi_manage_menu() {
		local config_file; config_file=$(_cliproxy_conf)

		while true; do
			clear

			local cp_installed cp_running cp_version cp_port cp_keys
			if is_macos; then
				cp_version=$(brew info cliproxyapi 2>/dev/null | awk 'NR==1{print $4}')
			else
				cp_version=$(cat "$(_cliproxy_dir)/version.txt" 2>/dev/null || echo "")
			fi
			if [[ -n "$cp_version" ]]; then
				cp_installed="\033[38;5;46m◉ INSTALLED  v${cp_version}\033[0m"
			else
				cp_installed="\033[90m○ NOT INSTALLED\033[0m"
			fi
			if _cliproxy_running; then
				cp_running="\033[38;5;46m▶ RUNNING\033[0m"
			else
				cp_running="\033[90m■ STOPPED\033[0m"
			fi
			cp_port=$(awk '/^port:/ { gsub(/[^0-9]/, "", $2); if ($2 != "") print $2; exit }' \
				"$config_file" 2>/dev/null)
			cp_port="${cp_port:-8317}"
			cp_keys=$(awk '/^api-keys:/{f=1;next} f&&/^[^ \t]/{exit} f&&/"sk-/{n++} END{print n+0}' \
				"$config_file" 2>/dev/null)

			gum style \
				--bold --foreground 51 \
				--border double --border-foreground 51 \
				--padding "1 4" --align center \
				"C L I P R O X Y A P I" \
				"" \
				"[ AI OAuth Proxy Manager ]"
			echo -e "  $cp_installed    $cp_running"
			echo -e "  \033[90m端口 :${cp_port}    API Keys: ${cp_keys}\033[0m"
			echo

			local choice
			choice=$(gum choose --cursor "❯ " \
			--header $'  ─── CLIProxyAPI ───\n  ↑↓ 移动 · Enter 确认 · / 搜索 · q 退出' \
				"启动" \
				"停止" \
				"重启" \
				"查看日志" \
				"账号授权登录" \
				"生成并添加 API Key" \
				"查看 API Keys" \
				"编辑配置文件" \
				"更新" \
				"卸载" \
				"退出") || break

			case "$choice" in
				"启动")
					_cliproxy_start_service
					break_end
					;;
				"停止")
					_cliproxy_stop_service
					break_end
					;;
				"重启")
					_cliproxy_stop_service
					sleep 1
					_cliproxy_start_service
					break_end
					;;
				"查看日志")
					echo
					if is_macos; then
						local brew_log
						brew_log="$(brew --prefix 2>/dev/null)/var/log/cliproxyapi.log"
						if [[ -f "$brew_log" ]]; then
							tail -80 "$brew_log"
						elif [[ -f /tmp/cliproxyapi.log ]]; then
							tail -80 /tmp/cliproxyapi.log
						else
							ui_warn "未找到日志（服务尚未运行过）"
						fi
					elif systemctl --user is-active --quiet cliproxyapi.service 2>/dev/null; then
						journalctl --user -u cliproxyapi.service --no-pager -n 80
					elif [[ -f /tmp/cliproxyapi.log ]]; then
						tail -80 /tmp/cliproxyapi.log
					else
						ui_warn "未找到日志（服务尚未运行过）"
					fi
					break_end
					;;
				"账号授权登录")
					_cliproxy_oauth_login
					break_end
					;;
				"生成并添加 API Key")
					if [[ ! -f "$config_file" ]]; then
						ui_err "未找到配置文件：$config_file"
						break_end
						continue
					fi
					local new_key
					new_key="sk-$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_letters+string.digits) for _ in range(48)))')"
					echo
					gum style --bold --foreground 46 "  ◉  已生成新 API Key："
					gum style --bold --foreground 51 "     $new_key"
					echo
					if gum confirm "  将此 Key 自动写入 config.yaml？"; then
						python3 - "$config_file" "$new_key" <<'PY'
import sys, re
path, key = sys.argv[1], sys.argv[2]
txt = open(path).read()
txt = re.sub(r'(api-keys:\s*\n)', r'\1  - "' + key + '"\n', txt, count=1)
open(path, 'w').write(txt)
print("写入成功")
PY
						ui_ok "API Key 已写入配置"
					fi
					break_end
					;;
				"查看 API Keys")
					echo
					if [[ -f "$config_file" ]]; then
						gum style --foreground 240 "  config.yaml 中的 API Keys："
						echo
						awk '/^api-keys:/{f=1;next} f&&/^[^ \t]/{exit} f&&/"sk-/{print "  " $0}' \
							"$config_file"
						echo
					else
						ui_warn "未找到配置文件：$config_file"
					fi
					break_end
					;;
				"编辑配置文件")
					if [[ -f "$config_file" ]]; then
						nano "$config_file"
					else
						ui_err "未找到配置文件：$config_file"
						break_end
					fi
					;;
				"更新")
					echo
					if gum confirm "  确认更新 CLIProxyAPI 到最新版本？"; then
						if is_macos; then
							brew upgrade cliproxyapi && ui_ok "更新完成"
						else
							curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer \
								| bash -s -- upgrade
							ui_ok "更新完成"
						fi
					fi
					break_end
					;;
				"卸载")
					echo
					if gum confirm "  ⚡ 确认卸载 CLIProxyAPI？"; then
						_cliproxy_stop_service 2>/dev/null || true
						if is_macos; then
							brew uninstall cliproxyapi 2>/dev/null || true
							rm -rf "$HOME/.cli-proxy-api"
						else
							systemctl --user disable cliproxyapi.service >/dev/null 2>&1 || true
							rm -f "$HOME/.config/systemd/user/cliproxyapi.service" 2>/dev/null || true
							rm -rf "$(_cliproxy_dir)"
						fi
						ui_ok "CLIProxyAPI 已卸载"
					fi
					break_end
					;;
				"退出"|*)
					break
					;;
			esac
		done
	}

	beginner_mode_install() {
		if is_macos; then
			gum style \
				--bold --foreground 201 \
				--border double --border-foreground 201 \
				--padding "1 6" --align center \
				"◈  EASY INSTALL  ◈" \
				"" \
				"[ OpenClaw  ⟶  API Key 配置 ]"
		else
			gum style \
				--bold --foreground 201 \
				--border double --border-foreground 201 \
				--padding "1 6" --align center \
				"◈  EASY INSTALL  ◈" \
				"" \
				"[ OpenClaw  ⟶  CLIProxyAPI  ⟶  AI Auth  ⟶  Auto Config ]"
		fi
		echo

		ui_step "第 1 步：安装 OpenClaw"
		_install_openclaw_core

		ui_step "第 2 步：安装 CLIProxyAPI"
		if is_macos; then
			if ! gum spin --spinner globe --title "正在安装 CLIProxyAPI..." -- \
					brew install cliproxyapi; then
				ui_err "CLIProxyAPI 安装失败（brew install cliproxyapi）"
				break_end
				return 1
			fi
		else
			if ! curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash; then
				ui_err "CLIProxyAPI 安装失败"
				break_end
				return 1
			fi
		fi

		local cliproxy_config; cliproxy_config=$(_cliproxy_conf)
		if [[ ! -f "$cliproxy_config" ]]; then
			ui_err "CLIProxyAPI 安装后未找到配置文件: $cliproxy_config"
			break_end
			return 1
		fi
		ui_ok "CLIProxyAPI 安装完成"

		ui_step "第 3 步：登录 AI 账号"
		ui_info "通过 OAuth 授权即可免费使用，无需付费 API Key"
		echo
		_cliproxy_oauth_login

		ui_step "第 4 步：生成 API Key 并启动服务"
		local new_key
		new_key="sk-$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_letters+string.digits) for _ in range(48)))')"
		python3 - "$cliproxy_config" "$new_key" <<'PY' 2>/dev/null
import sys, re
path, key = sys.argv[1], sys.argv[2]
txt = open(path).read()
txt = re.sub(r'(api-keys:\s*\n(?:\s*-\s*"[^"]*"\s*\n)*)', lambda m: m.group(0) + f'  - "{key}"\n', txt, count=1)
open(path, 'w').write(txt)
PY
		if ! _cliproxy_start_service; then
			break_end
			return 1
		fi

		ui_step "第 5 步：配置 OpenClaw API"

		local api_key port base_url
		api_key=$(awk '
			/^api-keys:/ { in_keys=1; next }
			in_keys && /^[^ \t]/ { exit }
			in_keys && /"sk-/ { match($0, /sk-[^"]+/); print substr($0, RSTART, RLENGTH); exit }
		' "$cliproxy_config" 2>/dev/null)

		port=$(awk '/^port:/ { gsub(/[^0-9]/, "", $2); if ($2 != "") print $2; exit }' "$cliproxy_config" 2>/dev/null)
		port="${port:-8317}"
		base_url="http://localhost:${port}/v1"

		if [[ -z "$api_key" ]]; then
			ui_err "无法从 $cliproxy_config 读取 API Key，请手动在「CLIProxyAPI 管理」中添加"
			break_end
			return 1
		fi

		ui_info "地址：$base_url"
		ui_info "Key：${api_key:0:12}****"
		echo

		install jq
		add-all-models-from-provider "cliproxy" "$base_url" "$api_key"

		if [[ $? -eq 0 ]]; then
			start_gateway

			ui_step "第 6 步：选择默认模型"
			ui_info "请从可用模型中选择一个作为默认，选完后网关自动重启"
			echo
			change_model

			echo
			gum style \
				--bold --foreground 46 \
				--border double --border-foreground 46 \
				--padding "1 6" --align center \
				"◉  INSTALL COMPLETE  ◉" \
				"" \
				"[ OpenClaw 已自动接入 CLIProxyAPI，可直接开始使用 ]" \
				"[ 更多提供商：cd ~/cliproxyapi && ./cli-proxy-api --help ]"
		fi

		echo
		if gum confirm "  现在去对接机器人？"; then
			change_tg_bot_code
		else
			break_end
		fi
	}

	start_bot() {
		start_gateway
		break_end
	}

	stop_bot() {
		tmux kill-session -t gateway > /dev/null 2>&1
		gum spin --spinner pulse --title "正在停止网关..." -- openclaw gateway stop
		break_end
	}

	view_logs() {
		openclaw status
		openclaw gateway status
		openclaw logs
		break_end
	}

	add-all-models-from-provider() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"
		local config_file="${HOME}/.openclaw/openclaw.json"

		local models_tmpfile
		models_tmpfile=$(mktemp)
		gum spin --spinner globe --title "正在获取 $provider_name 的模型列表..." -- \
			curl -s -m 10 -o "$models_tmpfile" \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models"

		local models_json
		models_json=$(cat "$models_tmpfile")
		rm -f "$models_tmpfile"

		if [[ -z "$models_json" ]]; then
			echo "错误：无法获取模型列表"
			return 1
		fi

		local model_ids
		model_ids=$(echo "$models_json" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    models = data.get("data", data) if isinstance(data, dict) else data
    for m in models:
        if isinstance(m, dict) and "id" in m:
            print(m["id"])
except Exception:
    pass
')

		if [[ -z "$model_ids" ]]; then
			echo "错误：未找到任何模型"
			return 1
		fi

		local model_count
		model_count=$(echo "$model_ids" | wc -l | tr -d ' ')
		echo "发现 $model_count 个模型"

		local models_array="["
		local first=true

		while read -r model_id; do
			[[ $first == false ]] && models_array+=","
			first=false

			local context_window=1048576
			local max_tokens=128000
			local input_cost=0.15
			local output_cost=0.60

			case "$model_id" in
				*opus*|*pro*|*preview*|*thinking*|*sonnet*)
					input_cost=2.00
					output_cost=12.00
					;;
				*gpt-5*|*codex*)
					input_cost=1.25
					output_cost=10.00
					;;
				*flash*|*lite*|*haiku*|*mini*|*nano*)
					input_cost=0.10
					output_cost=0.40
					;;
			esac

			models_array+=$(cat <<EOF
{
	"id": "$model_id",
	"name": "$provider_name / $model_id",
	"input": ["text", "image"],
	"contextWindow": $context_window,
	"maxTokens": $max_tokens,
	"cost": {
		"input": $input_cost,
		"output": $output_cost,
		"cacheRead": 0,
		"cacheWrite": 0
	}
}
EOF
)
		done <<< "$model_ids"

		models_array+="]"

		[[ -f "$config_file" ]] && cp "$config_file" "${config_file}.bak.$(date +%s)"

		jq --arg prov "$provider_name" \
		   --arg url "$base_url" \
		   --arg key "$api_key" \
		   --argjson models "$models_array" \
		'
		.models |= (
			(. // { mode: "merge", providers: {} })
			| .mode = "merge"
			| .providers[$prov] = {
				baseUrl: $url,
				apiKey: $key,
				api: "openai-completions",
				models: $models
			}
		)
		| .agents |= (. // {})
		| .agents.defaults |= (. // {})
		| .agents.defaults.models |= (
			(if type == "object" then .
			 elif type == "array" then reduce .[] as $m ({}; if ($m|type) == "string" then .[$m] = {} else . end)
			 else {}
			 end) as $existing
			| reduce ($models[]? | .id? // empty | tostring) as $mid (
				$existing;
				if ($mid | length) > 0 then
					.["\($prov)/\($mid)"] //= {}
				else
					.
				end
			)
		)
		' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

		if [[ $? -eq 0 ]]; then
			echo "成功添加 $model_count 个模型到 $provider_name"
			echo "模型引用格式: $provider_name/<model-id>"
			return 0
		else
			echo "错误：配置注入失败"
			return 1
		fi
	}

	add-openclaw-provider-interactive() {
		local provider_name base_url api_key

		provider_name=$(gum input \
			--placeholder "Provider 名称 (如: deepseek)" \
			--prompt "Provider > ")
		[[ -z "$provider_name" ]] && return 1

		base_url=$(gum input \
			--placeholder "Base URL (如: https://api.xxx.com/v1)" \
			--prompt "Base URL > ")
		[[ -z "$base_url" ]] && return 1
		base_url="${base_url%/}"

		api_key=$(gum input --password \
			--placeholder "API Key" \
			--prompt "API Key > ")
		[[ -z "$api_key" ]] && return 1

		local models_tmpfile models_json available_models model_count
		models_tmpfile=$(mktemp)
		gum spin --spinner globe --title "正在获取模型列表..." -- \
			curl -s -m 10 -o "$models_tmpfile" \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models"
		models_json=$(cat "$models_tmpfile")
		rm -f "$models_tmpfile"

		local default_model=""
		if [[ -n "$models_json" ]]; then
			available_models=$(echo "$models_json" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    models = data.get("data", data) if isinstance(data, dict) else data
    ids = sorted(m["id"] for m in models if isinstance(m, dict) and "id" in m)
    print("\n".join(ids))
except Exception:
    pass
')
			model_count=$(echo "$available_models" | wc -l | tr -d ' ')
		fi

		if [[ -n "$available_models" ]]; then
			default_model=$(echo "$available_models" | fzf \
				--prompt="  ❯ " \
				--header="  发现 $model_count 个模型  │  ↑↓ 移动  / 搜索  Enter 确认  Esc 选第一个" \
				--header-first \
				--height=15 \
				--layout=reverse \
				--border=double \
				--border-label=" ◈ DEFAULT MODEL " \
				--color=border:51,label:51,header:51,prompt:201,pointer:46,marker:208,hl:208,hl+:208) || default_model=$(echo "$available_models" | head -1)
			[[ -z "$default_model" ]] && default_model=$(echo "$available_models" | head -1)
			default_model=$(awk '{print $1}' <<< "$default_model")
		fi

		echo
		gum style \
			--border normal --border-foreground 99 \
			--padding "0 2" \
			"Provider  : $provider_name" \
			"Base URL  : $base_url" \
			"API Key   : ${api_key:0:8}****" \
			"默认模型  : $default_model" \
			"模型总数  : $model_count"
		echo

		gum confirm "确认添加所有 $model_count 个模型？" || { echo "已取消"; return 1; }

		install jq
		add-all-models-from-provider "$provider_name" "$base_url" "$api_key"

		if [[ $? -eq 0 ]]; then
			gum spin --spinner minidot --title "设置默认模型并重启网关..." -- \
				openclaw models set "$provider_name/$default_model"
			start_gateway
			echo "完成：所有 $model_count 个模型已加载"
		fi

		break_end
	}

	openclaw_api_manage_list() {
		local config_file="${HOME}/.openclaw/openclaw.json"

		while IFS=$'\t' read -r rec_type idx name base_url model_count latency_txt latency_level; do
			case "$rec_type" in
				MSG)
					echo "$idx"
					;;
				ROW)
					local latency_color="$gl_bai"
					case "$latency_level" in
						low)               latency_color="$gl_lv" ;;
						medium)            latency_color="$gl_huang" ;;
						high|unavailable)  latency_color="$gl_hong" ;;
						unchecked)         latency_color="$gl_bai" ;;
					esac

					printf '%b\n' "[$idx] ${name} | API: ${base_url} | 模型数量: ${gl_huang}${model_count}${gl_bai} | 延迟/状态: ${latency_color}${latency_txt}${gl_bai}"
					;;
			esac
		local _py_list; _py_list=$(mktemp /tmp/oc_list_XXXXXX.py)
		cat > "$_py_list" << 'PYEOF'
import json, sys, time, urllib.request

path = sys.argv[1]
SUPPORTED_APIS = {'openai-completions', 'openai-responses', 'openai-chat-completions'}

def ping_models(base_url, api_key):
    req = urllib.request.Request(
        base_url.rstrip('/') + '/models',
        headers={
            'Authorization': 'Bearer ' + api_key,
            'User-Agent': 'OpenClaw-API-Manage/1.0',
        },
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=4) as resp:
        resp.read(2048)
    return int((time.perf_counter() - start) * 1000)

def classify_latency(latency):
    if latency == '不可用':
        return '不可用', 'unavailable'
    if latency == '未检测':
        return '未检测', 'unchecked'
    if isinstance(latency, int):
        level = 'low' if latency <= 800 else ('medium' if latency <= 2000 else 'high')
        return str(latency) + 'ms', level
    return str(latency), 'unchecked'

try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
except FileNotFoundError:
    print('MSG\t未找到 openclaw.json，请先完成安装/初始化。')
    raise SystemExit(0)
except Exception as e:
    print('MSG\t读取配置失败: ' + type(e).__name__ + ': ' + str(e))
    raise SystemExit(0)

providers = ((obj.get('models') or {}).get('providers') or {})
if not isinstance(providers, dict) or not providers:
    print('MSG\t当前未配置任何 API provider。')
    raise SystemExit(0)

print('MSG\t--- 已配置 API 列表 ---')

for idx, name in enumerate(sorted(providers.keys()), start=1):
    provider = providers.get(name)
    if not isinstance(provider, dict):
        base_url = '-'; model_count = 0; latency_raw = '不可用'
    else:
        base_url = provider.get('baseUrl') or provider.get('url') or provider.get('endpoint') or '-'
        models = provider.get('models') if isinstance(provider.get('models'), list) else []
        model_count = sum(1 for m in models if isinstance(m, dict) and m.get('id'))
        api = provider.get('api', '')
        api_key = provider.get('apiKey')
        latency_raw = '未检测'
        if api in SUPPORTED_APIS and isinstance(base_url, str) and base_url != '-' and isinstance(api_key, str) and api_key:
            try:
                latency_raw = ping_models(base_url, api_key)
            except Exception:
                latency_raw = '不可用'
        elif api in SUPPORTED_APIS:
            latency_raw = '不可用'

    latency_text, latency_level = classify_latency(latency_raw)
    print('ROW\t' + '\t'.join([str(idx), str(name), str(base_url), str(model_count), str(latency_text), str(latency_level)]))
PYEOF
		done < <(python3 "$_py_list" "$config_file")
		rm -f "$_py_list"
	}

	sync-openclaw-provider-interactive() {
		local config_file="${HOME}/.openclaw/openclaw.json"

		if [[ ! -f "$config_file" ]]; then
			echo "错误：未找到配置文件: $config_file"
			break_end
			return 1
		fi

		local provider_name
		provider_name=$(gum input \
			--placeholder "要同步的 API 名称 (provider)" \
			--prompt "Provider > ")
		if [[ -z "$provider_name" ]]; then
			echo "错误：provider 名称不能为空"
			break_end
			return 1
		fi

		install jq curl >/dev/null 2>&1

		python3 - "$config_file" "$provider_name" <<'PY2'
import copy
import json
import sys
import time
import urllib.request

path = sys.argv[1]
target = sys.argv[2]
SUPPORTED_APIS = {'openai-completions', 'openai-responses', 'openai-chat-completions'}

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('错误：未检测到 API providers，无法同步')
    raise SystemExit(2)

provider = providers.get(target)
if not isinstance(provider, dict):
    print(f'错误：未找到 provider: {target}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def fetch_remote_models_with_retry(base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            return json.loads(payload), None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


api = provider.get('api', '')
base_url = provider.get('baseUrl')
api_key = provider.get('apiKey')
model_list = provider.get('models', [])

if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
    print(f'错误：provider {target} 缺少 baseUrl/apiKey/models，无法执行同步')
    raise SystemExit(3)

if api not in SUPPORTED_APIS:
    print(f'错误：provider {target} 当前 api={api}，不支持直接 /models 同步')
    raise SystemExit(3)

data, err, attempts = fetch_remote_models_with_retry(base_url, api_key, retries=3)
if err is not None:
    print(f'错误：{target}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
    raise SystemExit(4)

if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
    print(f'错误：{target}: /models 返回结构不可识别')
    raise SystemExit(4)

remote_ids = []
for item in data['data']:
    if isinstance(item, dict) and item.get('id'):
        remote_ids.append(str(item['id']))
remote_set = set(remote_ids)
if not remote_set:
    print(f'错误：{target}: 上游 /models 为空，已中止同步')
    raise SystemExit(5)

local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
local_ids = [str(m['id']) for m in local_models]
local_set = set(local_ids)

template = copy.deepcopy(local_models[0]) if local_models else None
if template is None:
    print(f'错误：{target}: 本地 models 无有效模板模型，无法补全新增模型')
    raise SystemExit(3)

removed_ids = [mid for mid in local_ids if mid not in remote_set]
added_ids = [mid for mid in remote_ids if mid not in local_set]

kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
new_models = kept_models[:]
for mid in added_ids:
    nm = copy.deepcopy(template)
    nm['id'] = mid
    if isinstance(nm.get('name'), str):
        nm['name'] = f'{target} / {mid}'
    new_models.append(nm)

if not new_models:
    print(f'错误：{target}: 同步后无可用模型，已中止写入')
    raise SystemExit(5)

expected_refs = {model_ref(target, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
local_refs = {model_ref(target, mid) for mid in local_ids}
removed_refs = local_refs - expected_refs
first_ref = model_ref(target, str(new_models[0]['id']))

changed = False
primary_ref = get_primary_ref(defaults)
if isinstance(primary_ref, str) and primary_ref in removed_refs:
    set_primary_ref(defaults, first_ref)
    changed = True
    print(f'默认模型已兜底替换: {primary_ref} -> {first_ref}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if isinstance(val, str) and val in removed_refs:
        defaults[fk] = first_ref
        changed = True
        print(f'{fk} 已兜底替换: {val} -> {first_ref}')

stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(target + '/') and r not in expected_refs]
for r in stale_refs:
    defaults_models.pop(r, None)
    changed = True

for r in sorted(expected_refs):
    if r not in defaults_models:
        defaults_models[r] = {}
        changed = True

if removed_ids or added_ids or len(local_models) != len(new_models):
    provider['models'] = new_models
    changed = True

if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')

print(f'{target}: 删除 {len(removed_ids)} 个，新增 {len(added_ids)} 个，当前 {len(new_models)} 个')
if changed:
    print('指定 provider 模型一致性同步完成')
else:
    print('无需同步：该 provider 配置已与上游 /models 保持一致')
PY2
		local rc=$?
		case "$rc" in
			0)
				echo "同步完成"
				start_gateway
				;;
			2) echo "错误：provider 不存在或未配置" ;;
			3) echo "错误：provider 配置不完整或类型不支持" ;;
			4) echo "错误：上游 /models 请求失败" ;;
			5) echo "错误：上游模型为空或同步后无可用模型" ;;
			*) echo "错误：请检查配置文件结构或日志输出" ;;
		esac

		break_end
	}

	delete-openclaw-provider-interactive() {
		local config_file="${HOME}/.openclaw/openclaw.json"

		if [[ ! -f "$config_file" ]]; then
			echo "错误：未找到配置文件: $config_file"
			break_end
			return 1
		fi

		local provider_name
		provider_name=$(gum input \
			--placeholder "要删除的 API 名称 (provider)" \
			--prompt "Provider > ")
		if [[ -z "$provider_name" ]]; then
			echo "错误：provider 名称不能为空"
			break_end
			return 1
		fi

		python3 - "$config_file" "$provider_name" <<'PY'
import copy
import json
import sys

path = sys.argv[1]
name = sys.argv[2]

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or name not in providers:
    print(f'错误：未找到 provider: {name}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


replacement_candidates = collect_available_refs(exclude_provider=name)
replacement = replacement_candidates[0] if replacement_candidates else None

primary_ref = get_primary_ref(defaults)
if ref_provider(primary_ref) == name:
    if not replacement:
        print('错误：删除中止：默认主模型指向该 provider，且无可用替代模型')
        raise SystemExit(3)
    set_primary_ref(defaults, replacement)
    print(f'默认主模型切换: {primary_ref} -> {replacement}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if ref_provider(val) == name:
        if not replacement:
            print(f'错误：删除中止：{fk} 指向该 provider，且无可用替代模型')
            raise SystemExit(3)
        defaults[fk] = replacement
        print(f'{fk} 切换: {val} -> {replacement}')

removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
for r in removed_refs:
    defaults_models.pop(r, None)

providers.pop(name, None)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(work, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f'已删除 provider: {name}')
print(f'已清理 defaults.models 中 {len(removed_refs)} 个关联模型引用')
PY
		local rc=$?
		case "$rc" in
			0)
				echo "删除完成"
				start_gateway
				;;
			2) echo "错误：provider 不存在" ;;
			3) echo "错误：无可用替代模型，已保持原配置" ;;
			*) echo "错误：请检查配置文件结构或日志输出" ;;
		esac

		break_end
	}

	openclaw_api_manage_menu() {
		while true; do
			clear
			ui_header "API 管理"
			openclaw_api_manage_list
			echo

			local api_choice
			api_choice=$(gum choose --cursor "❯ " \
				--header $'选择操作\n↑↓ 移动 · Enter 确认 · q 退出' \
				"添加 API" \
				"同步 API 供应商模型列表" \
				"删除 API" \
				"返回") || return 0

			case "$api_choice" in
				"添加 API")              add-openclaw-provider-interactive ;;
				"同步 API 供应商模型列表") sync-openclaw-provider-interactive ;;
				"删除 API")              delete-openclaw-provider-interactive ;;
				"返回"|*)                return 0 ;;
			esac
		done
	}

	change_model() {
		local all_models model
		all_models=$(openclaw models list --all 2>/dev/null | grep "configured")

		if [[ -z "$all_models" ]]; then
			ui_err "无法获取可用模型列表（请先添加 API 提供商）"
			break_end
			return
		fi

		model=$(echo "$all_models" | fzf \
			--prompt="  ❯ " \
			--header="  当前: $(openclaw models list 2>/dev/null | awk '{print $1}' | head -1)  │  ↑↓ 移动  / 搜索  Enter 确认  Esc 取消" \
			--header-first \
			--height=20 \
			--layout=reverse \
			--border=double \
			--border-label=" ◈ MODEL SELECT " \
			--color=border:51,label:51,header:51,prompt:201,pointer:46,marker:208,hl:208,hl+:208) || return

		[[ -z "$model" ]] && return
		model=$(awk '{print $1}' <<< "$model")

		gum spin --spinner minidot --title "正在切换模型..." -- openclaw models set "$model"
		start_gateway
		ui_ok "已切换至：$model"
		break_end
	}

	resolve_openclaw_plugin_id() {
		local raw_input="$1"
		local plugin_id="$raw_input"

		plugin_id="${plugin_id#@openclaw/}"
		if [[ "$plugin_id" == @*/* ]]; then
			plugin_id="${plugin_id##*/}"
		fi
		plugin_id="${plugin_id%%@*}"
		echo "$plugin_id"
	}

	sync_openclaw_plugin_allowlist() {
		local plugin_id="$1"
		[[ -z "$plugin_id" ]] && return 1

		local home_config="${HOME}/.openclaw/openclaw.json"
		local root_config="/root/.openclaw/openclaw.json"
		local config_file="$home_config"
		if [[ ! -f "$home_config" && -f "$root_config" ]]; then
			config_file="$root_config"
		fi

		mkdir -p "$(dirname "$config_file")"
		if [[ ! -s "$config_file" ]]; then
			echo '{}' > "$config_file"
		fi

		if command -v jq >/dev/null 2>&1; then
			local tmp_json
			tmp_json=$(mktemp)
			if jq --arg pid "$plugin_id" '
				.plugins = (if (.plugins | type) == "object" then .plugins else {} end)
				| .plugins.allow = (if (.plugins.allow | type) == "array" then .plugins.allow else [] end)
				| if (.plugins.allow | index($pid)) == null then .plugins.allow += [$pid] else . end
			' "$config_file" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$config_file"; then
				echo "已同步 plugins.allow 白名单: $plugin_id"
				return 0
			fi
			rm -f "$tmp_json"
		fi

		if command -v python3 >/dev/null 2>&1; then
			if python3 - "$config_file" "$plugin_id" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}

a = plugins.get('allow')
if not isinstance(a, list):
    a = []

if plugin_id not in a:
    a.append(plugin_id)

plugins['allow'] = a
data['plugins'] = plugins
config_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PYTHON_EOF
			then
				echo "已同步 plugins.allow 白名单: $plugin_id"
				return 0
			fi
		fi

		echo "警告：已安装插件，但同步 plugins.allow 失败，请手动检查: $config_file"
		return 1
	}

	install_plugin() {
		while true; do
			clear
			ui_header "插件管理"
			gum style --foreground 240 "当前已安装插件:"
			openclaw plugins list
			echo
			gum style --bold --foreground 99 "常用插件参考:"
			printf "  \033[96m%-20s\033[0m  %s\n" "feishu"         "飞书/Lark 集成"
			printf "  \033[96m%-20s\033[0m  %s\n" "telegram"       "Telegram 机器人"
			printf "  \033[96m%-20s\033[0m  %s\n" "slack"          "Slack 企业通讯"
			printf "  \033[96m%-20s\033[0m  %s\n" "msteams"        "Microsoft Teams"
			printf "  \033[96m%-20s\033[0m  %s\n" "discord"        "Discord 社区管理"
			printf "  \033[96m%-20s\033[0m  %s\n" "whatsapp"       "WhatsApp 自动化"
			printf "  \033[96m%-20s\033[0m  %s\n" "memory-core"    "基础记忆 (文件检索)"
			printf "  \033[96m%-20s\033[0m  %s\n" "memory-lancedb" "增强记忆 (向量数据库)"
			printf "  \033[96m%-20s\033[0m  %s\n" "copilot-proxy"  "Copilot 接口转发"
			printf "  \033[96m%-20s\033[0m  %s\n" "lobster"        "审批流 (带人工确认)"
			printf "  \033[96m%-20s\033[0m  %s\n" "voice-call"     "语音通话能力"
			printf "  \033[96m%-20s\033[0m  %s\n" "nostr"          "加密隐私聊天"
			echo

			local raw_input
			raw_input=$(gum input \
				--placeholder "插件 ID (留空退出)" \
				--prompt "Plugin > ")
			[[ -z "$raw_input" ]] && break

			local plugin_id plugin_full
			plugin_id=$(resolve_openclaw_plugin_id "$raw_input")
			plugin_full="$raw_input"

			local plugin_list
			plugin_list=$(openclaw plugins list 2>/dev/null)

			if echo "$plugin_list" | grep -qw "$plugin_id" && echo "$plugin_list" | grep "$plugin_id" | grep -q "disabled"; then
				ui_info "插件 [$plugin_id] 已预装，正在激活..."
				openclaw plugins enable "$plugin_id" && ui_ok "激活成功" || ui_err "激活失败"
			elif [[ -d "/usr/lib/node_modules/openclaw/extensions/$plugin_id" ]]; then
				ui_info "发现系统内置插件，尝试直接启用..."
				openclaw plugins enable "$plugin_id"
			else
				ui_info "本地未发现，尝试下载安装..."
				rm -rf "/root/.openclaw/extensions/$plugin_id"

				if openclaw plugins install "$plugin_full"; then
					ui_ok "下载成功，正在启用..."
					openclaw plugins enable "$plugin_id"
				else
					ui_warn "官方渠道下载失败，尝试 npm 备选方案..."
					if npm install -g "$plugin_full" --unsafe-perm; then
						ui_ok "npm 安装成功，尝试启用..."
						openclaw plugins enable "$plugin_id"
					else
						ui_err "无法获取该插件，请检查 ID 是否正确或网络是否可用"
						break_end
						continue
					fi
				fi
			fi

			sync_openclaw_plugin_allowlist "$plugin_id"
			start_gateway
			break_end
		done
	}

	install_skill() {
		while true; do
			clear
			ui_header "技能管理"
			gum style --foreground 240 "当前已安装技能:"
			openclaw skills list
			echo
			gum style --bold --foreground 99 "推荐技能参考:"
			printf "  \033[96m%-22s\033[0m  %s\n" "github"          "管理 GitHub Issues/PR/CI"
			printf "  \033[96m%-22s\033[0m  %s\n" "notion"          "操作 Notion 页面与数据库"
			printf "  \033[96m%-22s\033[0m  %s\n" "apple-notes"     "macOS 原生笔记管理"
			printf "  \033[96m%-22s\033[0m  %s\n" "apple-reminders" "macOS 提醒事项管理"
			printf "  \033[96m%-22s\033[0m  %s\n" "1password"       "自动化读取 1Password 密钥"
			printf "  \033[96m%-22s\033[0m  %s\n" "gog"             "Google Workspace 全能助手"
			printf "  \033[96m%-22s\033[0m  %s\n" "things-mac"      "Things 3 任务管理"
			printf "  \033[96m%-22s\033[0m  %s\n" "bluebubbles"     "通过 BlueBubbles 收发 iMessage"
			printf "  \033[96m%-22s\033[0m  %s\n" "himalaya"        "终端邮件管理 (IMAP/SMTP)"
			printf "  \033[96m%-22s\033[0m  %s\n" "summarize"       "网页/播客/YouTube 内容总结"
			printf "  \033[96m%-22s\033[0m  %s\n" "openai-whisper"  "本地音频转文字"
			printf "  \033[96m%-22s\033[0m  %s\n" "coding-agent"    "运行 Claude Code/Codex 等编程助手"
			echo

			local skill_name
			skill_name=$(gum input \
				--placeholder "技能名称 (留空退出)" \
				--prompt "Skill > ")
			[[ -z "$skill_name" ]] && break

			local skill_found=false
			if [[ -d "${HOME}/.openclaw/workspace/skills/${skill_name}" ]]; then
				echo "技能 [$skill_name] 已在用户目录安装"
				skill_found=true
			elif [[ -d "/usr/lib/node_modules/openclaw/skills/${skill_name}" ]]; then
				echo "技能 [$skill_name] 已在系统目录安装"
				skill_found=true
			fi

			if [[ "$skill_found" == true ]]; then
				gum confirm "是否重新安装？" || { break_end; continue; }
			fi

			gum spin --spinner globe --title "正在安装技能 $skill_name..." -- npx clawhub install "$skill_name"
			if [[ $? -eq 0 ]]; then
				echo "技能 $skill_name 安装成功"
				start_gateway
			else
				echo "错误：安装失败，请检查技能名称是否正确"
			fi

			break_end
		done
	}

	openclaw_json_get_bool() {
		local expr="$1"
		local config_file="${HOME}/.openclaw/openclaw.json"
		if [[ ! -s "$config_file" ]]; then
			echo "false"
			return
		fi
		jq -r "$expr" "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_channel_has_cfg() {
		local channel="$1"
		local config_file="${HOME}/.openclaw/openclaw.json"
		if [[ ! -s "$config_file" ]]; then
			echo "false"
			return
		fi
		jq -r --arg c "$channel" '
			(.channels[$c] // null) as $v
			| if ($v | type) != "object" then
				false
			  else
				([ $v
				   | to_entries[]
				   | select((.key == "enabled" or .key == "dmPolicy" or .key == "groupPolicy" or .key == "streaming") | not)
				   | .value
				   | select(. != null and . != "" and . != false)
				 ] | length) > 0
			  end
		' "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_dir_has_files() {
		local dir="$1"
		[[ -d "$dir" ]] && find "$dir" -type f -print -quit 2>/dev/null | grep -q .
	}

	openclaw_plugin_local_installed() {
		local plugin="$1"
		local config_file="${HOME}/.openclaw/openclaw.json"
		if [[ -s "$config_file" ]] && jq -e --arg p "$plugin" '.plugins.installs[$p]' "$config_file" >/dev/null 2>&1; then
			return 0
		fi
		[[ -d "${HOME}/.openclaw/extensions/${plugin}" ]] || [[ -d "/usr/lib/node_modules/openclaw/extensions/${plugin}" ]]
	}

	openclaw_bot_status_text() {
		local enabled="$1"
		local configured="$2"
		local connected="$3"
		local abnormal="$4"
		if [[ "$abnormal" == "true" ]]; then
			echo "异常"
		elif [[ "$enabled" != "true" ]]; then
			echo "未启用"
		elif [[ "$connected" == "true" ]]; then
			echo "已连接"
		elif [[ "$configured" == "true" ]]; then
			echo "已配置"
		else
			echo "未配置"
		fi
	}

	openclaw_colorize_bot_status() {
		local status="$1"
		case "$status" in
			已连接) echo -e "${gl_lv}${status}${gl_bai}" ;;
			已配置) echo -e "${gl_huang}${status}${gl_bai}" ;;
			异常)   echo -e "${gl_hong}${status}${gl_bai}" ;;
			*)      echo "$status" ;;
		esac
	}

	openclaw_print_bot_status_line() {
		local label="$1"
		local status="$2"
		echo -e "- ${label}: $(openclaw_colorize_bot_status "$status")"
	}

	openclaw_show_bot_local_status_block() {
		local config_file="${HOME}/.openclaw/openclaw.json"
		local json_ok="false"
		if [[ -s "$config_file" ]] && jq empty "$config_file" >/dev/null 2>&1; then
			json_ok="true"
		fi

		local tg_enabled tg_cfg tg_connected tg_abnormal tg_status
		tg_enabled=$(openclaw_json_get_bool '.channels.telegram.enabled // .plugins.entries.telegram.enabled // false')
		tg_cfg=$(openclaw_channel_has_cfg "telegram")
		tg_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/telegram"; then
			tg_connected="true"
		fi
		tg_abnormal="false"
		if [[ "$tg_enabled" == "true" && "$json_ok" != "true" ]]; then
			tg_abnormal="true"
		fi
		tg_status=$(openclaw_bot_status_text "$tg_enabled" "$tg_cfg" "$tg_connected" "$tg_abnormal")

		local feishu_enabled feishu_cfg feishu_connected feishu_abnormal feishu_status
		feishu_enabled=$(openclaw_json_get_bool '.plugins.entries.feishu.enabled // .channels.feishu.enabled // false')
		feishu_cfg=$(openclaw_channel_has_cfg "feishu")
		feishu_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/feishu"; then
			feishu_connected="true"
		fi
		feishu_abnormal="false"
		if [[ "$feishu_enabled" == "true" ]] && ! openclaw_plugin_local_installed "feishu"; then
			feishu_abnormal="true"
		fi
		if [[ "$feishu_enabled" == "true" && "$json_ok" != "true" ]]; then
			feishu_abnormal="true"
		fi
		feishu_status=$(openclaw_bot_status_text "$feishu_enabled" "$feishu_cfg" "$feishu_connected" "$feishu_abnormal")

		local wa_enabled wa_cfg wa_connected wa_abnormal wa_status
		wa_enabled=$(openclaw_json_get_bool '.plugins.entries.whatsapp.enabled // .channels.whatsapp.enabled // false')
		wa_cfg=$(openclaw_channel_has_cfg "whatsapp")
		wa_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/whatsapp"; then
			wa_connected="true"
		fi
		wa_abnormal="false"
		if [[ "$wa_enabled" == "true" ]] && ! openclaw_plugin_local_installed "whatsapp"; then
			wa_abnormal="true"
		fi
		if [[ "$wa_enabled" == "true" && "$json_ok" != "true" ]]; then
			wa_abnormal="true"
		fi
		wa_status=$(openclaw_bot_status_text "$wa_enabled" "$wa_cfg" "$wa_connected" "$wa_abnormal")

		local dc_enabled dc_cfg dc_connected dc_abnormal dc_status
		dc_enabled=$(openclaw_json_get_bool '.channels.discord.enabled // .plugins.entries.discord.enabled // false')
		dc_cfg=$(openclaw_channel_has_cfg "discord")
		dc_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/discord"; then
			dc_connected="true"
		fi
		dc_abnormal="false"
		if [[ "$dc_enabled" == "true" && "$json_ok" != "true" ]]; then
			dc_abnormal="true"
		fi
		dc_status=$(openclaw_bot_status_text "$dc_enabled" "$dc_cfg" "$dc_connected" "$dc_abnormal")

		local slack_enabled slack_cfg slack_connected slack_abnormal slack_status
		slack_enabled=$(openclaw_json_get_bool '.plugins.entries.slack.enabled // .channels.slack.enabled // false')
		slack_cfg=$(openclaw_channel_has_cfg "slack")
		slack_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/slack"; then
			slack_connected="true"
		fi
		slack_abnormal="false"
		if [[ "$slack_enabled" == "true" ]] && ! openclaw_plugin_local_installed "slack"; then
			slack_abnormal="true"
		fi
		if [[ "$slack_enabled" == "true" && "$json_ok" != "true" ]]; then
			slack_abnormal="true"
		fi
		slack_status=$(openclaw_bot_status_text "$slack_enabled" "$slack_cfg" "$slack_connected" "$slack_abnormal")

		local qq_enabled qq_cfg qq_connected qq_abnormal qq_status
		qq_enabled=$(openclaw_json_get_bool '.plugins.entries.qqbot.enabled // .channels.qqbot.enabled // false')
		qq_cfg=$(openclaw_channel_has_cfg "qqbot")
		qq_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/qqbot/sessions" || openclaw_dir_has_files "${HOME}/.openclaw/qqbot/data"; then
			qq_connected="true"
		fi
		qq_abnormal="false"
		if [[ "$qq_enabled" == "true" ]] && ! openclaw_plugin_local_installed "qqbot"; then
			qq_abnormal="true"
		fi
		if [[ "$qq_enabled" == "true" && "$json_ok" != "true" ]]; then
			qq_abnormal="true"
		fi
		qq_status=$(openclaw_bot_status_text "$qq_enabled" "$qq_cfg" "$qq_connected" "$qq_abnormal")

		echo "本地状态（仅本机配置/缓存，不做网络探测）："
		openclaw_print_bot_status_line "Telegram"   "$tg_status"
		openclaw_print_bot_status_line "飞书(Lark)" "$feishu_status"
		openclaw_print_bot_status_line "WhatsApp"   "$wa_status"
		openclaw_print_bot_status_line "Discord"    "$dc_status"
		openclaw_print_bot_status_line "Slack"      "$slack_status"
		openclaw_print_bot_status_line "QQ Bot"     "$qq_status"
	}

	change_tg_bot_code() {
		while true; do
			clear
			ui_header "机器人连接对接"
			openclaw_show_bot_local_status_block
			echo

			local bot_choice
			bot_choice=$(gum choose --cursor "❯ " \
				--header $'选择要对接的平台\n↑↓ 移动 · Enter 确认 · q 退出' \
				"Telegram 机器人对接" \
				"飞书 (Lark) 机器人对接" \
				"WhatsApp 机器人对接" \
				"返回") || return 0

			local code
			case "$bot_choice" in
				"Telegram 机器人对接")
					code=$(gum input \
						--placeholder "TG机器人连接码 (例如 NYA99R2F)" \
						--prompt "连接码 > ")
					[[ -z "$code" ]] && continue
					openclaw pairing approve telegram "$code"
					break_end
					;;
				"飞书 (Lark) 机器人对接")
					code=$(gum input \
						--placeholder "飞书机器人连接码 (例如 NYA99R2F)" \
						--prompt "连接码 > ")
					[[ -z "$code" ]] && continue
					openclaw pairing approve feishu "$code"
					break_end
					;;
				"WhatsApp 机器人对接")
					code=$(gum input \
						--placeholder "WhatsApp连接码 (例如 NYA99R2F)" \
						--prompt "连接码 > ")
					[[ -z "$code" ]] && continue
					openclaw pairing approve whatsapp "$code"
					break_end
					;;
				"返回"|*)
					return 0
					;;
			esac
		done
	}

	openclaw_backup_root() {
		echo "${HOME}/.openclaw/backups"
	}

	openclaw_is_interactive_terminal() {
		[[ -t 0 && -t 1 ]]
	}

	openclaw_has_command() {
		command -v "$1" >/dev/null 2>&1
	}

	openclaw_is_safe_relpath() {
		local rel="$1"
		[[ -z "$rel" ]] && return 1
		[[ "$rel" == /* ]] && return 1
		[[ "$rel" == *//* ]] && return 1
		[[ "$rel" == *$'\n'* ]] && return 1
		[[ "$rel" == *$'\r'* ]] && return 1
		case "$rel" in
			../*|*/../*|*/..|..)
				return 1
				;;
		esac
		return 0
	}

	openclaw_restore_path_allowed() {
		local mode="$1"
		local rel="$2"
		case "$mode" in
			memory)
				case "$rel" in
					MEMORY.md|AGENTS.md|USER.md|SOUL.md|TOOLS.md|memory/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			project)
				case "$rel" in
					openclaw.json|workspace/*|extensions/*|skills/*|prompts/*|tools/*|telegram/*|feishu/*|whatsapp/*|discord/*|slack/*|qqbot/*|logs/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			*)
				return 1
				;;
		esac
	}

	openclaw_pack_backup_archive() {
		local backup_type="$1"
		local export_mode="$2"
		local payload_dir="$3"
		local output_file="$4"

		local tmp_root
		tmp_root=$(mktemp -d) || return 1
		local pack_dir="$tmp_root/package"
		mkdir -p "$pack_dir"

		cp -a "$payload_dir" "$pack_dir/payload"

		(
			cd "$pack_dir/payload" || exit 1
			find . -type f | sed 's|^\./||' | sort > "$pack_dir/manifest.files"
			: > "$pack_dir/manifest.sha256"
			local f
			while IFS= read -r f; do
				[[ -z "$f" ]] && continue
				sha256sum "$f" >> "$pack_dir/manifest.sha256"
			done < "$pack_dir/manifest.files"
		) || { rm -rf "$tmp_root"; return 1; }

		cat > "$pack_dir/backup.meta" <<EOF
TYPE=$backup_type
MODE=$export_mode
CREATED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
HOST=$(hostname)
EOF

		mkdir -p "$(dirname "$output_file")"
		tar -C "$pack_dir" -czf "$output_file" backup.meta manifest.files manifest.sha256 payload
		local rc=$?
		rm -rf "$tmp_root"
		return $rc
	}

	openclaw_offer_transfer_hint() {
		local file_path="$1"
		echo "可使用以下方式下载备份文件："
		echo "  本地路径: $file_path"
		echo "  scp 示例: scp root@你的服务器:$file_path ./"
		echo "  或使用 SFTP 客户端下载"
	}

	openclaw_prepare_import_archive() {
		local expected_type="$1"
		local archive_path="$2"
		local unpack_root="$3"

		if [[ ! -f "$archive_path" ]]; then
			echo "错误：文件不存在: $archive_path"
			return 1
		fi
		mkdir -p "$unpack_root"
		if ! tar -xzf "$archive_path" -C "$unpack_root"; then
			echo "错误：备份包解压失败"
			return 1
		fi

		local pkg_dir="$unpack_root/package"
		if [[ -f "$unpack_root/backup.meta" ]]; then
			pkg_dir="$unpack_root"
		fi

		local required
		for required in backup.meta manifest.files manifest.sha256 payload; do
			if [[ ! -e "$pkg_dir/$required" ]]; then
				echo "错误：备份包缺少必要文件: $required"
				return 1
			fi
		done

		local real_type
		real_type=$(grep '^TYPE=' "$pkg_dir/backup.meta" | head -n1 | cut -d'=' -f2-)
		if [[ "$real_type" != "$expected_type" ]]; then
			echo "错误：备份类型不匹配，期望: $expected_type，实际: ${real_type:-未知}"
			return 1
		fi

		(
			cd "$pkg_dir/payload" || exit 1
			sha256sum -c ../manifest.sha256 >/dev/null
		) || { echo "错误：sha256 校验失败，拒绝还原"; return 1; }

		echo "$pkg_dir"
		return 0
	}

	openclaw_memory_backup_export() {
		local workspace_dir="${HOME}/.openclaw/workspace"
		local backup_root
		backup_root=$(openclaw_backup_root)
		local ts
		ts=$(date +%Y%m%d-%H%M%S)
		local out_file="$backup_root/openclaw-memory-full-${ts}.tar.gz"

		mkdir -p "$backup_root"
		if [[ ! -d "$workspace_dir" ]]; then
			echo "错误：未找到 workspace 目录: $workspace_dir"
			break_end
			return 1
		fi

		local tmp_payload
		tmp_payload=$(mktemp -d) || return 1

		[[ -f "$workspace_dir/MEMORY.md" ]] && cp -a "$workspace_dir/MEMORY.md" "$tmp_payload/"
		[[ -d "$workspace_dir/memory" ]]    && cp -a "$workspace_dir/memory"    "$tmp_payload/"

		if gum confirm "是否附带 AGENTS/USER/SOUL/TOOLS 文件？"; then
			local f
			for f in AGENTS.md USER.md SOUL.md TOOLS.md; do
				[[ -f "$workspace_dir/$f" ]] && cp -a "$workspace_dir/$f" "$tmp_payload/"
			done
		fi

		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "错误：未找到可备份的记忆文件"
			rm -rf "$tmp_payload"
			break_end
			return 1
		fi

		if gum spin --spinner meter --title "正在打包备份..." -- \
			openclaw_pack_backup_archive "memory-full" "default" "$tmp_payload" "$out_file"; then
			echo "记忆全量备份完成: $out_file"
			openclaw_offer_transfer_hint "$out_file"
		else
			echo "错误：记忆全量备份失败"
		fi

		rm -rf "$tmp_payload"
		break_end
	}

	openclaw_read_import_path() {
		local file_input file_path backup_root
		echo "提示：输入文件名时默认在备份目录查找；输入含 / 的路径时按完整路径校验。" >&2
		echo "scp 示例: scp /本地/备份包.tar.gz root@你的服务器:/tmp/" >&2

		file_input=$(gum input \
			--placeholder "备份文件名或完整路径" \
			--prompt "Path > ")
		[[ -z "$file_input" ]] && { echo ""; return 0; }

		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"

		if [[ "$file_input" == */* ]]; then
			file_path="$file_input"
		else
			file_path="$backup_root/$file_input"
		fi

		if [[ ! -f "$file_path" ]]; then
			echo "错误：备份文件不存在: $file_path" >&2
			echo ""
			return 1
		fi

		echo "$file_path"
	}

	openclaw_memory_backup_import() {
		local workspace_dir="${HOME}/.openclaw/workspace"
		mkdir -p "$workspace_dir"

		local archive_path
		archive_path=$(openclaw_read_import_path)
		if [[ -z "$archive_path" ]]; then
			echo "错误：未输入备份路径"
			break_end
			return 1
		fi

		local tmp_unpack pkg_dir
		tmp_unpack=$(mktemp -d) || return 1
		pkg_dir=$(openclaw_prepare_import_archive "memory-full" "$archive_path" "$tmp_unpack")
		if [[ $? -ne 0 ]]; then
			rm -rf "$tmp_unpack"
			break_end
			return 1
		fi

		local invalid=0
		local valid_list
		valid_list=$(mktemp)
		local rel
		while IFS= read -r rel; do
			[[ -z "$rel" ]] && continue
			if ! openclaw_is_safe_relpath "$rel" || ! openclaw_restore_path_allowed memory "$rel"; then
				echo "错误：检测到非法或越权路径: $rel"
				invalid=1
				break
			fi
			echo "$rel" >> "$valid_list"
		done < "$pkg_dir/manifest.files"

		if [[ "$invalid" -ne 0 ]]; then
			rm -f "$valid_list"
			rm -rf "$tmp_unpack"
			echo "错误：还原中止：存在不安全路径"
			break_end
			return 1
		fi

		while IFS= read -r rel; do
			mkdir -p "$workspace_dir/$(dirname "$rel")"
			cp -a "$pkg_dir/payload/$rel" "$workspace_dir/$rel"
		done < "$valid_list"

		rm -f "$valid_list"
		rm -rf "$tmp_unpack"
		echo "记忆全量还原完成"
		break_end
	}

	openclaw_project_backup_export() {
		local openclaw_root="${HOME}/.openclaw"
		if [[ ! -d "$openclaw_root" ]]; then
			echo "错误：未找到 OpenClaw 根目录: $openclaw_root"
			break_end
			return 1
		fi

		local export_mode_label
		export_mode_label=$(gum choose --cursor "❯ " \
			--header $'选择备份模式\n↑↓ 移动 · Enter 确认 · q 取消' \
			"安全模式（推荐）：workspace + openclaw.json + extensions/skills/prompts/tools" \
			"完整模式（含更多状态，敏感风险更高）") || return 1

		local mode_label="safe"
		local tmp_payload
		tmp_payload=$(mktemp -d) || return 1

		local d
		if [[ "$export_mode_label" == 完整* ]]; then
			mode_label="full"
			for d in workspace extensions skills prompts tools; do
				[[ -e "$openclaw_root/$d" ]] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
			[[ -f "$openclaw_root/openclaw.json" ]] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in telegram feishu whatsapp discord slack qqbot logs; do
				[[ -e "$openclaw_root/$d" ]] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		else
			[[ -d "$openclaw_root/workspace" ]]    && cp -a "$openclaw_root/workspace"    "$tmp_payload/"
			[[ -f "$openclaw_root/openclaw.json" ]] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in extensions skills prompts tools; do
				[[ -e "$openclaw_root/$d" ]] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		fi

		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "错误：未找到可备份的 OpenClaw 项目内容"
			rm -rf "$tmp_payload"
			break_end
			return 1
		fi

		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		local out_file="$backup_root/openclaw-project-${mode_label}-$(date +%Y%m%d-%H%M%S).tar.gz"

		if gum spin --spinner meter --title "正在打包备份..." -- \
			openclaw_pack_backup_archive "openclaw-project" "$mode_label" "$tmp_payload" "$out_file"; then
			echo "OpenClaw 项目备份完成 (${mode_label}): $out_file"
			openclaw_offer_transfer_hint "$out_file"
		else
			echo "错误：OpenClaw 项目备份失败"
		fi

		rm -rf "$tmp_payload"
		break_end
	}

	openclaw_project_backup_import() {
		local openclaw_root="${HOME}/.openclaw"
		mkdir -p "$openclaw_root"

		echo "警告：高风险操作，项目还原会覆盖 OpenClaw 配置与工作区内容。"
		gum confirm "确认继续还原？此操作不可逆。" || { echo "已取消"; break_end; return 1; }

		local archive_path
		archive_path=$(openclaw_read_import_path)
		if [[ -z "$archive_path" ]]; then
			echo "错误：未输入备份路径"
			break_end
			return 1
		fi

		local tmp_unpack pkg_dir
		tmp_unpack=$(mktemp -d) || return 1
		pkg_dir=$(openclaw_prepare_import_archive "openclaw-project" "$archive_path" "$tmp_unpack")
		if [[ $? -ne 0 ]]; then
			rm -rf "$tmp_unpack"
			break_end
			return 1
		fi

		local invalid=0
		local valid_list
		valid_list=$(mktemp)
		local rel
		while IFS= read -r rel; do
			[[ -z "$rel" ]] && continue
			if ! openclaw_is_safe_relpath "$rel" || ! openclaw_restore_path_allowed project "$rel"; then
				echo "错误：检测到非法或越权路径: $rel"
				invalid=1
				break
			fi
			echo "$rel" >> "$valid_list"
		done < "$pkg_dir/manifest.files"

		if [[ "$invalid" -ne 0 ]]; then
			rm -f "$valid_list"
			rm -rf "$tmp_unpack"
			echo "错误：还原中止：存在不安全路径"
			break_end
			return 1
		fi

		if command -v openclaw >/dev/null 2>&1; then
			gum spin --spinner pulse --title "停止 OpenClaw gateway..." -- openclaw gateway stop
		fi

		while IFS= read -r rel; do
			mkdir -p "$openclaw_root/$(dirname "$rel")"
			cp -a "$pkg_dir/payload/$rel" "$openclaw_root/$rel"
		done < "$valid_list"

		if command -v openclaw >/dev/null 2>&1; then
			start_gateway
			echo "gateway 健康检查："
			openclaw gateway status || true
		fi

		rm -f "$valid_list"
		rm -rf "$tmp_unpack"
		echo "OpenClaw 项目还原完成"
		break_end
	}

	openclaw_backup_detect_type() {
		local file_name="$1"
		if [[ "$file_name" == openclaw-memory-full-*.tar.gz ]]; then
			echo "记忆备份文件"
		elif [[ "$file_name" == openclaw-project-*.tar.gz ]]; then
			echo "项目备份文件"
		else
			echo "其他备份文件"
		fi
	}

	openclaw_backup_collect_files() {
		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		mapfile -t OPENCLAW_BACKUP_FILES < <(find "$backup_root" -maxdepth 1 -type f -name '*.tar.gz' | xargs -I{} basename {} | sort -r)
	}

	openclaw_backup_render_file_list() {
		local backup_root i file_name file_path file_type file_size file_time
		local has_memory=0 has_project=0 has_other=0
		backup_root=$(openclaw_backup_root)
		openclaw_backup_collect_files

		echo "备份目录: $backup_root"
		if [[ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]]; then
			echo "暂无备份文件"
			return 0
		fi

		for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
			file_type=$(openclaw_backup_detect_type "${OPENCLAW_BACKUP_FILES[$i]}")
			case "$file_type" in
				"记忆备份文件") has_memory=1 ;;
				"项目备份文件") has_project=1 ;;
				"其他备份文件") has_other=1 ;;
			esac
		done

		if [[ "$has_memory" -eq 1 ]]; then
			echo "记忆备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[[ "$file_type" != "记忆备份文件" ]] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "  %s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [[ "$has_project" -eq 1 ]]; then
			echo "项目备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[[ "$file_type" != "项目备份文件" ]] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "  %s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [[ "$has_other" -eq 1 ]]; then
			echo "其他备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[[ "$file_type" != "其他备份文件" ]] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "  %s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi
	}

	openclaw_backup_file_exists_in_list() {
		local target_file="$1"
		local item
		for item in "${OPENCLAW_BACKUP_FILES[@]}"; do
			[[ "$item" == "$target_file" ]] && return 0
		done
		return 1
	}

	openclaw_backup_delete_file() {
		local backup_root backup_root_real user_input target_file target_path target_type
		backup_root=$(openclaw_backup_root)

		openclaw_backup_render_file_list
		if [[ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]]; then
			break_end
			return 0
		fi

		user_input=$(printf '%s\n' "${OPENCLAW_BACKUP_FILES[@]}" | fzf \
			--prompt="  ❯ " \
			--header="  选择要删除的备份  │  ↑↓ 移动  / 搜索  Enter 确认  Esc 取消" \
			--header-first \
			--height=15 \
			--border=double \
			--border-label=" ⚡ DELETE BACKUP " \
			--color=border:196,label:196,header:196,prompt:208,pointer:196,marker:208,hl:208,hl+:208) || { echo "已取消"; break_end; return 0; }

		[[ -z "$user_input" ]] && { echo "已取消"; break_end; return 0; }

		backup_root_real=$(realpath -m "$backup_root")
		target_file=$(basename -- "$user_input")
		target_path="$backup_root/$target_file"

		if [[ ! -f "$target_path" ]]; then
			echo "错误：目标文件不存在: $target_path"
			break_end
			return 1
		fi

		target_type=$(openclaw_backup_detect_type "$target_file")

		echo "即将删除: [$target_type] $target_path"
		gum confirm "确认删除？" || { echo "已取消删除"; break_end; return 0; }
		gum confirm "请再次确认，删除后不可恢复" || { echo "已取消删除"; break_end; return 0; }

		if rm -f -- "$target_path"; then
			echo "删除成功: $target_file"
		else
			echo "错误：删除失败: $target_file"
		fi
		break_end
	}

	openclaw_backup_list_files() {
		openclaw_backup_render_file_list
		break_end
	}

	openclaw_backup_restore_menu() {
		while true; do
			clear
			ui_header "备份与还原"
			openclaw_backup_render_file_list
			echo

			local backup_choice
			backup_choice=$(gum choose --cursor "❯ " \
				--header $'选择操作\n↑↓ 移动 · Enter 确认 · q 退出' \
				"备份记忆全量" \
				"还原记忆全量" \
				"备份 OpenClaw 项目（安全模式）" \
				"还原 OpenClaw 项目（高风险）" \
				"删除备份文件" \
				"返回") || return 0

			case "$backup_choice" in
				"备份记忆全量")               openclaw_memory_backup_export ;;
				"还原记忆全量")               openclaw_memory_backup_import ;;
				"备份 OpenClaw 项目（安全模式）") openclaw_project_backup_export ;;
				"还原 OpenClaw 项目（高风险）")  openclaw_project_backup_import ;;
				"删除备份文件")               openclaw_backup_delete_file ;;
				"返回"|*)                    return 0 ;;
			esac
		done
	}

	update_moltbot() {
		install_node_and_tools
		if is_macos; then
			gum spin --spinner globe --title "正在更新 OpenClaw..." -- \
				env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest
		else
			gum spin --spinner globe --title "正在更新 OpenClaw..." -- npm install -g openclaw@latest
		fi
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		start_gateway
		hash -r
		ui_ok "更新完成"
		break_end
	}

	uninstall_moltbot() {
		gum confirm "确认卸载 OpenClaw？此操作不可逆。" || return 0

		gum spin --spinner meter --title "正在卸载 OpenClaw..." -- openclaw uninstall
		npm uninstall -g openclaw
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		rm -rf /root/.openclaw ~/.openclaw
		hash -r

		rm -f "$HOME/.local/bin/oc" "$HOME/.local/bin/openclawctl.sh" /usr/local/bin/oc
		for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
			[[ -f "$rc" ]] && _sed_i '/\.local\/bin.*PATH/d' "$rc"
		done

		ui_ok "卸载完成"
		break_end
	}

	nano_openclaw_json() {
		install nano
		nano ~/.openclaw/openclaw.json
		start_gateway
	}

	openclaw_find_webui_domain() {
		local conf domain_list
		domain_list=$(
			grep -R "18789" /home/web/conf.d/*.conf 2>/dev/null \
			| awk -F: '{print $1}' \
			| sort -u \
			| while read -r conf; do
				basename "$conf" .conf
			done
		)

		if [[ -n "$domain_list" ]]; then
			echo "$domain_list"
		fi
	}

	openclaw_show_webui_addr() {
		local local_ip token domains

		local_ip="127.0.0.1"
		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)

		gum style --border normal --border-foreground 99 --padding "0 2" \
			"OpenClaw WebUI 访问地址" \
			"本机: http://${local_ip}:18789/#token=${token}"

		domains=$(openclaw_find_webui_domain)
		if [[ -n "$domains" ]]; then
			echo "$domains" | while read -r d; do
				echo "域名: https://${d}/#token=${token}"
			done
		fi
	}

	openclaw_domain_webui() {
		add_yuming
		ldnmp_Proxy "${yuming}" 127.0.0.1 18789

		local token
		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)

		clear
		echo "访问地址: https://${yuming}/#token=$token"
		echo "先访问URL触发设备ID，然后回车下一步进行配对。"
		gum input --placeholder "按回车继续..." > /dev/null

		echo -e "${gl_kjlan}正在加载设备列表……${gl_bai}"

		local config_file="$HOME/.openclaw/openclaw.json"
		if [[ -f "$config_file" ]]; then
			local new_origin="https://${yuming}"
			if command -v jq >/dev/null 2>&1; then
				local tmp_json
				tmp_json=$(mktemp)
				jq 'if .gateway.controlUi == null then .gateway.controlUi = {"allowedOrigins": ["http://127.0.0.1"]} else . end | if (.gateway.controlUi.allowedOrigins | contains([$origin]) | not) then .gateway.controlUi.allowedOrigins += [$origin] else . end' \
					--arg origin "$new_origin" "$config_file" > "$tmp_json" && mv "$tmp_json" "$config_file"
				echo -e "${gl_kjlan}已将域名 ${yuming} 加入 allowedOrigins 配置${gl_bai}"
				openclaw gateway restart >/dev/null 2>&1
			fi
		fi

		openclaw devices list

		local Request_Key
		Request_Key=$(gum input \
			--placeholder "Request_Key" \
			--prompt "> ")

		if [[ -z "$Request_Key" ]]; then
			echo "Request_Key 不能为空"
			return 1
		fi

		openclaw devices approve "$Request_Key"
	}

	openclaw_remove_domain() {
		echo "域名格式 example.com 不带https://"
		web_del
	}

	openclaw_webui_menu() {
		while true; do
			clear
			ui_header "WebUI 访问与设置"
			openclaw_show_webui_addr
			echo

			local choice
			choice=$(gum choose --cursor "❯ " \
				--header $'选择操作\n↑↓ 移动 · Enter 确认 · q 退出' \
				"添加域名访问" \
				"删除域名访问" \
				"退出") || break

			case "$choice" in
				"添加域名访问")
					openclaw_domain_webui
					echo
					gum input --placeholder "按回车返回..." > /dev/null
					;;
				"删除域名访问")
					openclaw_remove_domain
					gum input --placeholder "按回车返回..." > /dev/null
					;;
				"退出"|*)
					break
					;;
			esac
		done
	}

	while true; do
		clear

		local install_status running_status update_info
		install_status=$(get_install_status)
		running_status=$(get_running_status)
		update_info=$(check_openclaw_update)

		gum style \
			--bold --foreground 51 \
			--border double --border-foreground 51 \
			--padding "1 8" --align center \
			"O P E N C L A W" \
			"" \
			"[ AI Agent Gateway Manager ]"
		echo -e "  $install_status    $running_status    $update_info"
		gum style --foreground 240 "  输入 oc 可快速启动"
		echo
		gum style \
			--bold \
			--border double --border-foreground 201 \
			--padding "0 4" --align center \
			"$(gum style --bold --foreground 201 '◈  by Joey  ◈')" \
			"$(gum style --bold --foreground 51  '▶  YouTube   @joeyblog')" \
			"$(gum style --bold --foreground 51  '▶  Telegram  t.me/+ft-zI76oovgwNmRh')" \
			"$(gum style --foreground 208        '⚡ 基于：kejilion · cliproxyapi-installer')"
		echo

		local choice
		choice=$(gum choose \
			--height 24 \
			--cursor "❯ " \
			--header $'  ─── CONTROL CENTER ───\n  ↑↓ 移动 · Enter 确认 · / 搜索 · q 退出' \
			"小白模式安装（推荐）" \
			"安装" \
			"启动" \
			"停止" \
			"状态日志查看" \
			"换模型" \
			"API管理" \
			"CLIProxyAPI 管理" \
			"机器人连接对接" \
			"安装插件" \
			"安装技能" \
			"编辑主配置文件" \
			"配置向导" \
			"健康检测与修复" \
			"WebUI访问与设置" \
			"TUI命令行对话" \
			"备份与还原" \
			"更新" \
			"卸载" \
			"退出") || break

		case "$choice" in
			"小白模式安装（推荐）") beginner_mode_install ;;
			"安装")         install_moltbot ;;
			"启动")         start_bot ;;
			"停止")         stop_bot ;;
			"状态日志查看") view_logs ;;
			"换模型")       change_model ;;
		"API管理")           openclaw_api_manage_menu ;;
		"CLIProxyAPI 管理") cliproxyapi_manage_menu ;;
		"机器人连接对接")    change_tg_bot_code ;;
			"安装插件")     install_plugin ;;
			"安装技能")     install_skill ;;
			"编辑主配置文件") nano_openclaw_json ;;
			"配置向导")
				openclaw onboard --install-daemon
				break_end
				;;
			"健康检测与修复")
				gum spin --spinner meter --title "正在执行健康检测..." -- openclaw doctor --fix
				if sync_openclaw_api_models; then
					start_gateway
				else
					ui_err "API 模型同步失败，已中止重启网关，请检查 provider /models 返回后重试"
				fi
				break_end
				;;
			"WebUI访问与设置") openclaw_webui_menu ;;
			"TUI命令行对话")
				openclaw tui
				break_end
				;;
			"备份与还原")   openclaw_backup_restore_menu ;;
			"更新")         update_moltbot ;;
			"卸载")         uninstall_moltbot ;;
			"退出"|*)       break ;;
		esac
	done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	moltbot_menu
fi
