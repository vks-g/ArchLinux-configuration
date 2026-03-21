#!/usr/bin/env python3
import sqlite3
import json
import os
import sys
import calendar
from datetime import date, timedelta

DB_PATH = os.path.expanduser("~/.local/share/focustime/focustime.db")

def main():
    target_date_str = date.today().isoformat()
    if len(sys.argv) > 1:
        target_date_str = sys.argv[1]
    
    try:
        target_date = date.fromisoformat(target_date_str)
    except ValueError:
        target_date = date.today()

    if not os.path.exists(DB_PATH):
        print(json.dumps({"total": 0, "current": "History", "apps": [], "week": [], "month": []}))
        return

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (target_date.isoformat(),))
    total_seconds = c.fetchone()[0] or 0

    c.execute('''
        SELECT app_class, COALESCE(app_title, app_class), seconds 
        FROM focus_log 
        WHERE log_date = ? 
        ORDER BY seconds DESC 
    ''', (target_date.isoformat(),))
    
    all_apps = []
    for row in c.fetchall():
        app_class, app_title, secs = row
        percentage = (secs / total_seconds) * 100 if total_seconds > 0 else 0
        all_apps.append({
            "name": app_title,
            "seconds": secs,
            "percent": round(percentage, 1)
        })
    
    monday = target_date - timedelta(days=target_date.weekday())
    days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    week_data = []
    
    for i in range(7):
        d = monday + timedelta(days=i)
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (d.isoformat(),))
        tot = c.fetchone()[0] or 0
        week_data.append({
            "date": d.isoformat(),
            "day": days_str[i],
            "total": tot,
            "is_target": d == target_date
        })

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
        "current": "History",
        "apps": all_apps,
        "week": week_data,
        "month": month_data
    }
    
    print(json.dumps(result))

if __name__ == "__main__":
    main()
