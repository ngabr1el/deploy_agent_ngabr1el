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

copy_core_files() {
    local f
    for f in attendance_checker.py config.json assets.csv; do
        [ -f "$TEMPLATE_DIR/$f" ] || { echo "[ERROR] Missing template: $TEMPLATE_DIR/$f"; return 1; }
    done
    cp "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py" &&
    cp "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/config.json" || {
        echo "[ERROR] Could not copy template files (check permissions)."
        return 1
    }
    echo "[OK] Copied attendance_checker.py and config.json"
}

ask_student_count() {
    local max="$1" n
    while true; do
        read -r -p "How many students? (1-$max): " n || return 1
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$max" ]; then
            STUDENT_COUNT=$((10#$n))
            return 0
        fi
        echo "Please enter a whole number from 1 to $max."
    done
}

roster_from_template() {
    local max
    max=$(( $(awk 'END{print NR}' "$TEMPLATE_DIR/assets.csv") - 1 ))
    ask_student_count "$max" || return 1
    head -n $((STUDENT_COUNT + 1)) "$TEMPLATE_DIR/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv" || {
        echo "[ERROR] Could not write assets.csv."
        return 1
    }
    echo "[OK] Copied $STUDENT_COUNT student(s) from the template (total_sessions stays 5)"
}

roster_generated() {
    local names=("Aline Mukamana" "Eric Habimana" "Diane Uwase" "Patrick Niyonzima" "Claudine Ingabire" "Jean Nshuti" "Sandra Mutesi" "Olivier Hakizimana" "Beata Umutoni" "Samuel Kamanzi")
    local emails=("aline@example.com" "eric@example.com" "diane@example.com" "patrick@example.com" "claudine@example.com" "jean@example.com" "sandra@example.com" "olivier@example.com" "beata@example.com" "samuel@example.com")
    local i
    ask_student_count "${#names[@]}" || return 1
    {
        echo "Email,Names,Attendance Count,Absence Count"
        for ((i = 0; i < STUDENT_COUNT; i++)); do
            echo "${emails[i]},${names[i]},0,0"
        done
    } > "$PROJECT_DIR/Helpers/assets.csv" || {
        echo "[ERROR] Could not write assets.csv."
        return 1
    }
    sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json" || {
        echo "[ERROR] Could not update total_sessions."
        return 1
    }
    echo "[OK] Generated $STUDENT_COUNT student(s) with zero counts (total_sessions set to 1)"
}

build_roster() {
    local pick
    echo "How should the student roster be built?"
    echo "  A) Copy from templates/assets.csv"
    echo "  B) Generate a fresh roster (all counts start at 0)"
    while true; do
        read -r -p "Choose A or B: " pick || return 1
        case "$pick" in
            A|a) roster_from_template; return $? ;;
            B|b) roster_generated; return $? ;;
            *) echo "Please type A or B." ;;
        esac
    done
}


deploy() {
	echo ">> Deploy feature"
	preflight_checks || return 1
	get_project_name || return 1
       	handle_existing_dir || return 1
        create_structure || return 1
	copy_core_files || return 1
	build_roster || return 1
	echo ">> Files deployed (permissions and thresholds not done yet)"
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
