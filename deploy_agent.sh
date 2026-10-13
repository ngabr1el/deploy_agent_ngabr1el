#!/bin/bash
#Writing the frame of deploy_agent.sh a menu that loops until you choose Exit with an empty function for each feature

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
TEMPLATE_DIR="$SCRIPT_DIR/templates"

preflight_checks() {
	echo "Pre-flight checks"
	local missing=0
	if command -v python3 >/dev/null 2>&1; then
		echo "[OK] $(python3 --version 2>&1)"
	else
		echo "[FAIL] python3 is not installed."
		missing=1
	fi
	if command -v zip >/dev/null 2>&1; then
		echo "[OK] zip is installed"
	else
		echo "[FAIL] zip is not installed."
		missing=1
	fi
	if [ "$missing" -eq 1 ]; then
		echo "Install the missing tool(s) and try again."
		return 1
	fi
	return 0
}
get_project_name() {
	local name
	while true; do
		read -r -p "Enter a name for the project: " name || return 1
		if [ -z "$name" ]; then
			echo "Name cannot be empty."
		elif [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
			echo "Use only letters, numbers, '_' or '-'."
		else
			break
		fi
	done
	PROJECT_NAME="$name"
	PROJECT_DIR="attendance_tracker_${name}"
}

handle_existing_dir() {
	if [ -e "$PROJECT_DIR" ]; then
		echo "'$PROJECT_DIR' already exists."
		read -r -p "Overwrite it? (y/n): " answer
		case "$answer" in 
			y|Y)
				rm -rf "$PROJECT_DIR" || { echo "[ERROR] Could not remove '$PROJECT_DIR'."; return 1; }
				echo "	Old project removed." ;;
				*)
				echo "Aborted. Nothing was changed."
				return 1 ;;
			esac
		fi
		return 0
}

create_structure() {
	mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" || {
		echo "[ERROR] Could not create directories (check permissions)."
		return 1
	}
	echo "[OK] Created $PROJECT_DIR/ with Helpers/ and reports/"
}


deploy() {
	echo ">> Deploy feature"
	preflight_checks || return 1
	get_project_name || return 1
       	handle_existing_dir || return 1
	create_structure || return 1
	echo ">> Structure created (files not copied yet)"
}

run_app() {
    echo ">> Run feature (not built yet)"
}

archive_logs() {
    echo ">> Archive feature (not built yet)"
}
show_menu() {
    echo "   Attendance Tracker Agent"
    echo "  1) Deploy a new project"
    echo "  2) Run an existing project"
    echo "  3) Archive logs"
    echo "  4) Exit"
}
main() {
    while true; do
        show_menu
        read -r -p "Choose an option [1-4]: " choice || { echo; echo "Goodbye."; exit 0; }
        case "$choice" in
            1) deploy ;;
            2) run_app ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice '$choice'. Please enter 1, 2, 3 or 4." ;;
        esac
    done
}
main
