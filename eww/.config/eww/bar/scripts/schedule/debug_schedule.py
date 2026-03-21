#!/usr/bin/env python3
import json
import re
import sys
import time
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

URL = "https://all.uddataplus.dk/skema/?id=id_menu_skema#menu_skema:" 
# PATH to the 'eww-schedule' profile folder you created
PROFILE_PATH = "/home/ilyamiro/.mozilla/firefox/21ersfgr.eww-shedule"


def debug_schedule():
    options = Options()
    # options.add_argument("--headless")  <--- COMMENTED OUT FOR DEBUGGING
    options.add_argument("-profile")
    options.add_argument(PROFILE_PATH)

    print("--> Launching Firefox...", file=sys.stderr)
    try:
        driver = webdriver.Firefox(options=options)
        
        print(f"--> Loading URL: {URL}", file=sys.stderr)
        driver.get(URL)

        # DEBUG: Check if we are stuck on login page
        time.sleep(2) # Give it a second to render visualy for you to see
        if "login" in driver.current_url.lower():
            print("ERROR: It redirected to the login page!", file=sys.stderr)
            print("ACTION: You need to log in manually in this window, check 'Remember Me', and close it.", file=sys.stderr)
            time.sleep(30) # Wait for you to login
            return

        print("--> Waiting for 'skemaBrikGruppe'...", file=sys.stderr)
        wait = WebDriverWait(driver, 15)
        wait.until(EC.presence_of_element_located((By.CLASS_NAME, "skemaBrikGruppe")))
        print("--> Found schedule container!", file=sys.stderr)

        # Find columns
        groups = driver.find_elements(By.XPATH, "//*[contains(@class, 'DagMedBrikker')]//*[contains(@class, 'skemaBrikGruppe')]/..")
        print(f"--> Found {len(groups)} day columns.", file=sys.stderr)

        def get_x_pos(elem):
            transform = elem.get_attribute("transform")
            if not transform: return 99999
            match = re.search(r"translate\((\d+)", transform)
            return int(match.group(1)) if match else 99999

        valid_groups = sorted(groups, key=get_x_pos)
        
        # DEBUG: Print found columns X positions
        for i, g in enumerate(valid_groups):
             print(f"    Column {i}: x={get_x_pos(g)}", file=sys.stderr)

        weekday = datetime.today().weekday()
        print(f"--> Today is weekday index: {weekday}", file=sys.stderr)

        if weekday >= len(valid_groups):
             print("--> Weekend or no data for today.", file=sys.stderr)
             return

        today_group = valid_groups[weekday]
        lessons = today_group.find_elements(By.XPATH, ".//*[local-name()='g'][count(*[local-name()='rect']) > 0]")
        print(f"--> Found {len(lessons)} lessons for today.", file=sys.stderr)

        data = []
        for i, lesson in enumerate(lessons):
            texts = lesson.find_elements(By.TAG_NAME, "text")
            print(f"    Lesson {i} has {len(texts)} text elements.", file=sys.stderr)
            if len(texts) >= 3:
                print(f"      Time: {texts[0].text} | Subj: {texts[1].text}", file=sys.stderr)
                data.append({
                    "time": texts[0].text,
                    "subject": texts[1].text,
                    "room": texts[2].text
                })

        print(json.dumps(data))

    except Exception as e:
        print("\n\nCRITICAL ERROR:", file=sys.stderr)
        print(str(e), file=sys.stderr)
        # Keep browser open for 10 seconds so you can see what happened
        time.sleep(10)

    finally:
        if 'driver' in locals():
            driver.quit()

if __name__ == "__main__":
    debug_schedule()
