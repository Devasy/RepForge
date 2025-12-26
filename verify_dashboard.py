from playwright.sync_api import sync_playwright
import time

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        # Set a mobile-like viewport
        page.set_viewport_size({"width": 375, "height": 812})

        print("Navigating to app...")
        # Increase timeout for initial load
        page.goto("http://localhost:8081", timeout=60000)
        page.wait_for_load_state("networkidle")

        # Check for onboarding
        print("Checking for onboarding...")

        # Wait a moment for animations
        time.sleep(2)

        # Try to find 'Get Started' or 'Skip' using more flexible locators
        try:
            # Look for the big blue button "Get Started"
            get_started = page.get_by_text("Get Started")
            if get_started.count() > 0 and get_started.first.is_visible():
                print("Found 'Get Started', clicking...")
                get_started.first.click()
                time.sleep(2)
            else:
                skip = page.get_by_text("Skip")
                if skip.count() > 0 and skip.first.is_visible():
                    print("Found 'Skip', clicking...")
                    skip.first.click()
                    time.sleep(2)
        except Exception as e:
            print(f"Error handling onboarding: {e}")

        # Now look for Progress tab
        print("Looking for Progress tab...")
        try:
            # Wait for the tab bar to appear
            progress_tab = page.get_by_text("Progress")
            progress_tab.wait_for(state="visible", timeout=10000)
            progress_tab.click()
            print("Clicked Progress tab.")

            # Wait for content to load
            time.sleep(3)

            # Verify specific dashboard elements
            print("Verifying dashboard content...")

            # Check for main sections
            # Header
            assert page.get_by_text("Progress Dashboard").is_visible()
            print("- Header found")

            # Streak metric
            # Use exact=True to avoid ambiguity with "Current Streak" if present
            assert page.get_by_text("Streak", exact=True).is_visible()
            print("- Streak metric found")

            # Workouts metric
            assert page.get_by_text("Workouts", exact=True).is_visible()
            print("- Workouts metric found")

            # Charts / Empty State
            if page.get_by_text("No data yet").is_visible():
                print("- Empty state found (No data yet)")
            else:
                # If data exists, check for chart titles
                assert page.get_by_text("Workout Frequency").is_visible()
                print("- Frequency chart title found")

                assert page.get_by_text("Volume by Muscle Group (30 days)").is_visible()
                print("- Volume chart title found")

                # Check recommendations
                assert page.get_by_text("Insights & Recommendations").is_visible()
                print("- Recommendations section found")

            print("Dashboard verification SUCCESS.")
            page.screenshot(path="verification_dashboard_success.png")

        except Exception as e:
            print(f"Dashboard verification FAILED: {e}")
            page.screenshot(path="verification_dashboard_failed_4.png")

        browser.close()

if __name__ == "__main__":
    run()
