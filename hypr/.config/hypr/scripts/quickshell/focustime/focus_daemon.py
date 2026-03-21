#!/usr/bin/env python3
import subprocess
import sqlite3
import time
import os
import socket
import json
import threading
import calendar
from datetime import date, timedelta

# Global state updated instantly by the IPC socket
current_app_class = "Desktop"
current_app_title = "Desktop"

# Ensure directories exist
DB_DIR = os.path.expanduser("~/.local/share/focustime")
os.makedirs(DB_DIR, exist_ok=True)
DB_PATH = os.path.join(DB_DIR, "focustime.db")

# Use fast RAM-disk (tmpfs) for the live state to prevent SSD wear
XDG_RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE_FILE = os.path.join(XDG_RUNTIME, "focustime_state.json")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS focus_log (
            log_date TEXT,
            app_class TEXT,
            seconds INTEGER,
            PRIMARY KEY (log_date, app_class)
        )
    ''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date)')
    
    # Safely migrate DB to support initialTitle
    c.execute("PRAGMA table_info(focus_log)")
    columns = [row[1] for row in c.fetchall()]
    if 'app_title' not in columns:
        c.execute('ALTER TABLE focus_log ADD COLUMN app_title TEXT')
        
    conn.commit()
    return conn

def get_active_window_hyprctl():
    try:
        output = subprocess.check_output(['hyprctl', 'activewindow', '-j'], text=True)
        if output.strip() == "{}": return "Desktop", "Desktop"
        data = json.loads(output)
        
        app_cls = data.get('initialClass') or data.get('class') or ''
        app_title = data.get('initialTitle') or data.get('title') or ''

        if "quickshell" in app_cls.lower() or "qs-master" in app_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"
            
        app_cls = app_cls if app_cls else "Unknown"
        app_title = app_title if app_title else app_cls
        return app_cls, app_title
    except Exception:
        return "Unknown", "Unknown"

def is_locked():
    try:
        subprocess.check_output(['pgrep', '-x', 'hyprlock'])
        return True
    except subprocess.CalledProcessError:
        return False

def listen_hyprland_ipc():
    global current_app_class, current_app_title
    hypr_sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not hypr_sig: return

    sock_path = f"{XDG_RUNTIME}/hypr/{hypr_sig}/.socket2.sock"
    if not os.path.exists(sock_path):
        sock_path = f"/tmp/hypr/{hypr_sig}/.socket2.sock"

    while True:
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(sock_path)
            buffer = ""
            while True:
                data = client.recv(4096).decode('utf-8')
                if not data: break
                buffer += data
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.startswith('activewindow>>'):
                        # Fetch the accurate initialClass and initialTitle 
                        cls, title = get_active_window_hyprctl()
                        if is_locked() or cls == "hyprlock":
                            current_app_class, current_app_title = "Locked", "Locked"
                        else:
                            current_app_class, current_app_title = cls, title
        except Exception:
            time.sleep(2) 

def dump_state_to_json(c):
    target_date = date.today()
    
    c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (target_date.isoformat(),))
    total_seconds = c.fetchone()[0] or 0

    # Fallback to app_class if app_title is missing (for older data entries)
    c.execute('''
        SELECT app_class, COALESCE(app_title, app_class), seconds 
        FROM focus_log 
        WHERE log_date = ? ORDER BY seconds DESC
    ''', (target_date.isoformat(),))
    
    all_apps = []
    for row in c.fetchall():
        app_class, app_title, secs = row
        percentage = (secs / total_seconds) * 100 if total_seconds > 0 else 0
        all_apps.append({"name": app_title, "seconds": secs, "percent": round(percentage, 1)})

    monday = target_date - timedelta(days=target_date.weekday())
    days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    week_data = []
    for i in range(7):
        d = monday + timedelta(days=i)
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (d.isoformat(),))
        tot = c.fetchone()[0] or 0
        week_data.append({"date": d.isoformat(), "day": days_str[i], "total": tot, "is_target": d == target_date})

    # Strict Calendar Month Heatmap Data
    month_data = []
    _, num_days = calendar.monthrange(target_date.year, target_date.month)
    first_day = target_date.replace(day=1)
    weekday_of_1st = first_day.weekday() # 0 is Monday

    # Pad the grid with invisible days so the 1st aligns with the correct row
    for _ in range(weekday_of_1st):
        month_data.append({"date": "", "total": -1, "is_target": False})

    # Fill actual month days
    for i in range(1, num_days + 1):
        d = target_date.replace(day=i)
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (d.isoformat(),))
        tot = c.fetchone()[0] or 0
        month_data.append({
            "date": d.isoformat(),
            "total": tot,
            "is_target": d == target_date
        })

    result = {
        "selected_date": target_date.isoformat(),
        "total": total_seconds,
        "current": current_app_title,
        "apps": all_apps,
        "week": week_data,
        "month": month_data
    }
    
    temp_file = STATE_FILE + ".tmp"
    try:
        with open(temp_file, "w") as f:
            json.dump(result, f)
        os.rename(temp_file, STATE_FILE)
    except Exception:
        pass

def main():
    global current_app_class, current_app_title
    current_app_class, current_app_title = get_active_window_hyprctl()
    
    ipc_thread = threading.Thread(target=listen_hyprland_ipc, daemon=True)
    ipc_thread.start()

    conn = init_db()
    c = conn.cursor()

    while True:
        time.sleep(1)
        
        if current_app_class and current_app_class not in ["Unknown", "Locked", "Quickshell", ""]:
            today = date.today().isoformat()
            c.execute('''
                INSERT INTO focus_log (log_date, app_class, seconds, app_title)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(log_date, app_class) 
                DO UPDATE SET seconds = seconds + 1, app_title = excluded.app_title
            ''', (today, current_app_class, 1, current_app_title))
            conn.commit()

        dump_state_to_json(c)

if __name__ == "__main__":
    main()
