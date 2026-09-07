import urllib.request
import urllib.parse
import http.cookiejar
import re
import sys
import io
from datetime import datetime, timedelta

# Fix Windows console utf-8 output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BASE_URL = "http://127.0.0.1:5000"

class TestClient:
    def __init__(self):
        self.cj = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.cj))

    def get(self, path):
        req = urllib.request.Request(f"{BASE_URL}{path}")
        resp = self.opener.open(req)
        return resp.status, resp.geturl(), resp.read().decode("utf-8")

    def post(self, path, data_dict):
        encoded_data = urllib.parse.urlencode(data_dict).encode("utf-8")
        req = urllib.request.Request(f"{BASE_URL}{path}", data=encoded_data)
        resp = self.opener.open(req)
        return resp.status, resp.geturl(), resp.read().decode("utf-8")


def run_e2e_test():
    print("======================================================================")
    print("      FOOD WASTE REDISTRIBUTION NETWORK — END-TO-END AUTOMATED TEST   ")
    print("======================================================================")

    # ──────────────────────────────────────────────────────────────────
    # Step 1: Register a new Donor
    # ──────────────────────────────────────────────────────────────────
    print("\n[STEP 1] Testing Donor Registration...")
    unique_email = f"bistro_{int(datetime.now().timestamp())}@example.com"
    donor_client = TestClient()

    reg_data = {
        "name": "Bistro Deluxe",
        "email": unique_email,
        "password": "Password@123",
        "role": "donor",
        "phone": "9876543299",
        "org_name": "Bistro Deluxe Cafe",
        "address": "101 Foodie Lane, Bangalore",
        "donor_type": "restaurant"
    }

    status, final_url, html = donor_client.post("/register", reg_data)
    print(f"  POST /register -> Status: {status}, Final URL: {final_url}")
    assert "/login" in final_url, f"Expected redirect to /login, got {final_url}"
    assert "Registration successful" in html or "Please log in" in html, "Registration success flash not found!"
    print("  ✓ Donor Registration passed successfully!")

    # ──────────────────────────────────────────────────────────────────
    # Step 2: Log in as that Donor & Post a Food Listing
    # ──────────────────────────────────────────────────────────────────
    print(f"\n[STEP 2] Logging in as new Donor ({unique_email}) & Posting Listing...")
    login_data = {"email": unique_email, "password": "Password@123"}
    status, final_url, html = donor_client.post("/login", login_data)
    print(f"  POST /login -> Status: {status}, Final URL: {final_url}")
    assert "/donor/dashboard" in final_url, f"Expected redirect to /donor/dashboard, got {final_url}"
    assert "Bistro Deluxe" in html or "Dashboard" in html, "Donor dashboard content missing"
    print("  ✓ Donor login successful!")

    # Post Listing
    expiry_time = (datetime.now() + timedelta(hours=10)).strftime("%Y-%m-%dT%H:%M")
    food_name = f"Fresh Pasta and Garlic Bread {int(datetime.now().timestamp()) % 1000}"
    listing_data = {
        "food_type": food_name,
        "quantity": "25.50",
        "expiry_datetime": expiry_time
    }
    status, final_url, html = donor_client.post("/donor/post-listing", listing_data)
    print(f"  POST /donor/post-listing -> Status: {status}, Final URL: {final_url}")
    assert "/donor/dashboard" in final_url, f"Expected redirect to /donor/dashboard, got {final_url}"
    assert food_name in html, f"Newly posted food listing '{food_name}' not visible on donor dashboard!"
    assert "available" in html.lower(), "Listing status not 'available'!"
    print(f"  ✓ Food listing '{food_name}' (25.50 kg) posted successfully!")

    # ──────────────────────────────────────────────────────────────────
    # Step 3: Log in as NGO, Claim Listing & Schedule Pickup
    # ──────────────────────────────────────────────────────────────────
    print("\n[STEP 3] Logging in as NGO (contact@sahararelief.ngo) & Claiming Listing...")
    ngo_client = TestClient()
    ngo_login_data = {"email": "contact@sahararelief.ngo", "password": "Password@123"}
    status, final_url, html = ngo_client.post("/login", ngo_login_data)
    print(f"  POST /login (NGO) -> Status: {status}, Final URL: {final_url}")
    assert "/ngo/dashboard" in final_url, f"Expected redirect to /ngo/dashboard, got {final_url}"
    assert food_name in html, f"Listing '{food_name}' not visible on NGO available listings dashboard!"
    print("  ✓ NGO logged in and sees the new listing on available dashboard!")

    # Find the claim button/action for this listing
    claim_match = re.search(r'action="/ngo/claim/(\d+)"', html)
    assert claim_match, "No claim form found on NGO dashboard!"
    listing_id = claim_match.group(1)
    print(f"  Found listing_id to claim: {listing_id}")

    # Submit claim
    status, final_url, claim_page_html = ngo_client.post(f"/ngo/claim/{listing_id}", {})
    print(f"  POST /ngo/claim/{listing_id} -> Status: {status}, Final URL: {final_url}")
    assert "/ngo/my-claims" in final_url, f"Expected redirect to /ngo/my-claims, got {final_url}"
    assert "Listing claimed" in claim_page_html or "Schedule a pickup below" in claim_page_html, "Claim flash message missing!"
    assert "Schedule Pickup" in claim_page_html, "'Schedule Pickup' button missing on My Claims page!"
    print("  ✓ Claim successful and redirected directly to /ngo/my-claims with 'Schedule Pickup' button!")

    # Find schedule pickup link
    sched_match = re.search(r'/ngo/schedule-pickup/(\d+)', claim_page_html)
    assert sched_match, "Schedule pickup link for claim not found on /ngo/my-claims!"
    claim_id = sched_match.group(1)
    print(f"  Found claim_id to schedule pickup: {claim_id}")

    # Schedule pickup
    pickup_time = (datetime.now() + timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M")
    sched_data = {"scheduled_time": pickup_time}
    status, final_url, sched_page_html = ngo_client.post(f"/ngo/schedule-pickup/{claim_id}", sched_data)
    print(f"  POST /ngo/schedule-pickup/{claim_id} -> Status: {status}, Final URL: {final_url}")
    assert "/ngo/my-claims" in final_url, f"Expected redirect to /ngo/my-claims, got {final_url}"
    assert "Pickup scheduled" in sched_page_html or "Scheduled" in sched_page_html, "Pickup status not shown as Scheduled!"
    print("  ✓ Pickup scheduled successfully and reflected on /ngo/my-claims!")

    # ──────────────────────────────────────────────────────────────────
    # Step 4: Log in as Admin & Verify Analytics Dashboard
    # ──────────────────────────────────────────────────────────────────
    print("\n[STEP 4] Logging in as Admin (admin@foodwaste.network) & Checking Analytics...")
    admin_client = TestClient()
    admin_login_data = {"email": "admin@foodwaste.network", "password": "Password@123"}
    status, final_url, admin_html = admin_client.post("/login", admin_login_data)
    print(f"  POST /login (Admin) -> Status: {status}, Final URL: {final_url}")
    assert "/admin/dashboard" in final_url, f"Expected redirect to /admin/dashboard, got {final_url}"
    assert "System Analytics" in admin_html or "Analytics" in admin_html, "Admin dashboard title missing!"

    # Verify key analytics sections exist
    sections = [
        "Q1 — Total Donations per Donor",
        "Q2 — Most Active NGOs",
        "Q3 — Expired",
        "Q5 — Currently Available Listings",
        "Q6 — Pickup Completion Rate",
        "Avg time-to-claim",
        "Pickup completion rate",
        "Total claims"
    ]
    for sec in sections:
        assert sec in admin_html, f"Analytics section '{sec}' not found in Admin Dashboard!"
        print(f"  ✓ Analytics section '{sec}' verified.")

    print("\n======================================================================")
    print("                     ALL 4 STEPS PASSED SUCCESSFULLY!                 ")
    print("======================================================================")

if __name__ == "__main__":
    try:
        run_e2e_test()
    except AssertionError as e:
        print(f"\n[FAIL] Assertion error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] Unexpected exception: {e}", file=sys.stderr)
        sys.exit(1)
