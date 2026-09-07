"""
app.py — Flask entry point for the Food Waste Redistribution Network.

Route map
---------
Auth
  GET/POST /register          — register as donor or ngo (admin blocked)
  GET/POST /login             — session-based login
  GET      /logout            — clear session

Donor  (role='donor' required)
  GET      /donor/dashboard           — own FoodListings
  GET/POST /donor/post-listing        — create new FoodListing

NGO  (role='ngo' required)
  GET      /ngo/dashboard             — GetAvailableListings() SP
  POST     /ngo/claim/<listing_id>    — ClaimListing() SP
  GET/POST /ngo/schedule-pickup/<claim_id> — insert Pickup

Admin  (role='admin' required)
  GET      /admin/dashboard           — all 6 analytics queries
"""

import os
from datetime import datetime, timezone
from functools import wraps

from flask import (
    Flask,
    flash,
    redirect,
    render_template,
    request,
    session,
    url_for,
)
from dotenv import load_dotenv
import mysql.connector
from werkzeug.security import check_password_hash, generate_password_hash

try:
    import bcrypt
except ImportError:
    bcrypt = None

from db import get_connection

def verify_password(stored_hash: str, candidate: str) -> bool:
    """Verify password against Werkzeug scrypt/pbkdf2 or bcrypt $2b$/$2a$ hashes."""
    if not stored_hash or not candidate:
        return False
    if stored_hash.startswith(("$2b$", "$2a$", "$2y$")) and bcrypt:
        try:
            return bcrypt.checkpw(candidate.encode("utf-8"), stored_hash.encode("utf-8"))
        except Exception:
            return False
    try:
        return check_password_hash(stored_hash, candidate)
    except Exception:
        return stored_hash == candidate

# ── App setup ────────────────────────────────────────────────────────────────
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-fallback-secret")


# ── Auth decorators ───────────────────────────────────────────────────────────
def login_required(f):
    """Redirect to /login if no active session."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            flash("Please log in to continue.", "warning")
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated


def role_required(*roles):
    """Reject users whose session role is not in the allowed set."""
    def decorator(f):
        @wraps(f)
        @login_required
        def decorated(*args, **kwargs):
            if session.get("role") not in roles:
                flash("You are not authorised to view that page.", "danger")
                return redirect(url_for("index"))
            return f(*args, **kwargs)
        return decorated
    return decorator


# ── Root ─────────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    if "role" in session:
        role = session["role"]
        if role == "donor":
            return redirect(url_for("donor_dashboard"))
        if role == "ngo":
            return redirect(url_for("ngo_dashboard"))
        if role == "admin":
            return redirect(url_for("admin_dashboard"))
    return redirect(url_for("login"))


# ── Auth routes ───────────────────────────────────────────────────────────────
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name     = request.form["name"].strip()
        email    = request.form["email"].strip().lower()
        password = request.form["password"]
        role     = request.form["role"]
        phone    = request.form.get("phone", "").strip() or None

        # ── Security: block admin self-registration ──
        if role not in ("donor", "ngo"):
            flash("Invalid role. Only 'donor' or 'ngo' accounts can be registered here.", "danger")
            return render_template("register.html")

        # Role-specific extra fields
        org_name = request.form.get("org_name", "").strip()
        address  = request.form.get("address", "").strip()

        if not org_name or not address:
            flash("Organisation name and address are required.", "danger")
            return render_template("register.html")

        pw_hash = generate_password_hash(password)
        conn = None
        try:
            conn = get_connection()
            cur = conn.cursor()

            # Parameterized INSERT — no string formatting of user input
            cur.execute(
                "INSERT INTO Users (name, email, password_hash, role, phone) "
                "VALUES (%s, %s, %s, %s, %s)",
                (name, email, pw_hash, role, phone),
            )
            user_id = cur.lastrowid

            if role == "donor":
                donor_type = request.form.get("donor_type", "restaurant")
                if donor_type not in ("restaurant", "store", "event"):
                    donor_type = "restaurant"
                cur.execute(
                    "INSERT INTO Donors (user_id, org_name, address, donor_type) "
                    "VALUES (%s, %s, %s, %s)",
                    (user_id, org_name, address, donor_type),
                )
            else:  # ngo
                capacity = request.form.get("capacity", "100")
                try:
                    capacity = int(capacity)
                except ValueError:
                    capacity = 100
                cur.execute(
                    "INSERT INTO NGOs (user_id, org_name, address, capacity) "
                    "VALUES (%s, %s, %s, %s)",
                    (user_id, org_name, address, capacity),
                )

            conn.commit()
            flash("Registration successful! Please log in.", "success")
            return redirect(url_for("login"))

        except mysql.connector.IntegrityError as e:
            if conn:
                conn.rollback()
            if "uq_users_email" in str(e) or "Duplicate entry" in str(e):
                flash("An account with that email already exists.", "danger")
            else:
                flash(f"Database error: {e}", "danger")
        except Exception as e:
            if conn:
                conn.rollback()
            flash(f"Unexpected error: {e}", "danger")
        finally:
            if conn:
                conn.close()

    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email    = request.form["email"].strip().lower()
        password = request.form["password"]

        conn = None
        try:
            conn = get_connection()
            cur = conn.cursor(dictionary=True)
            cur.execute(
                "SELECT user_id, name, password_hash, role FROM Users WHERE email = %s",
                (email,),
            )
            user = cur.fetchone()

            if not user or not verify_password(user["password_hash"], password):
                flash("Invalid email or password.", "danger")
                return render_template("login.html")

            # Store identity in session
            session["user_id"] = user["user_id"]
            session["name"]    = user["name"]
            session["role"]    = user["role"]

            # Also store the profile id (donor_id / ngo_id) for quick FK lookups
            if user["role"] == "donor":
                cur.execute(
                    "SELECT donor_id FROM Donors WHERE user_id = %s",
                    (user["user_id"],),
                )
                row = cur.fetchone()
                session["donor_id"] = row["donor_id"] if row else None
            elif user["role"] == "ngo":
                cur.execute(
                    "SELECT ngo_id FROM NGOs WHERE user_id = %s",
                    (user["user_id"],),
                )
                row = cur.fetchone()
                session["ngo_id"] = row["ngo_id"] if row else None

            flash(f"Welcome back, {user['name']}!", "success")
            return redirect(url_for("index"))

        except Exception as e:
            flash(f"Login error: {e}", "danger")
        finally:
            if conn:
                conn.close()

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


# ── Donor routes ──────────────────────────────────────────────────────────────
@app.route("/donor/dashboard")
@role_required("donor")
def donor_dashboard():
    donor_id = session["donor_id"]
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        # Only the logged-in donor's own listings (enforced via WHERE donor_id = %s)
        cur.execute(
            """
            SELECT listing_id, food_type, quantity, posted_at,
                   expiry_datetime, status
            FROM   FoodListings
            WHERE  donor_id = %s
            ORDER BY posted_at DESC
            """,
            (donor_id,),
        )
        listings = cur.fetchall()
    except Exception as e:
        flash(f"Could not load listings: {e}", "danger")
        listings = []
    finally:
        if conn:
            conn.close()
    return render_template("donor_dashboard.html", listings=listings)


@app.route("/donor/post-listing", methods=["GET", "POST"])
@role_required("donor")
def post_listing():
    if request.method == "POST":
        food_type       = request.form["food_type"].strip()
        quantity        = request.form["quantity"]
        expiry_datetime = request.form["expiry_datetime"]  # HTML datetime-local

        try:
            quantity = float(quantity)
            if quantity <= 0:
                raise ValueError("Quantity must be positive.")
            # Parse expiry from HTML datetime-local (no timezone suffix)
            expiry_dt = datetime.strptime(expiry_datetime, "%Y-%m-%dT%H:%M")
        except ValueError as e:
            flash(f"Invalid input: {e}", "danger")
            return render_template("post_listing.html")

        conn = None
        try:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute(
                """
                INSERT INTO FoodListings
                    (donor_id, food_type, quantity, posted_at, expiry_datetime, status)
                VALUES (%s, %s, %s, NOW(), %s, 'available')
                """,
                (session["donor_id"], food_type, quantity, expiry_dt),
            )
            conn.commit()
            flash("Food listing posted successfully!", "success")
            return redirect(url_for("donor_dashboard"))
        except Exception as e:
            if conn:
                conn.rollback()
            flash(f"Failed to post listing: {e}", "danger")
        finally:
            if conn:
                conn.close()

    return render_template("post_listing.html")


# ── Helper for query-time expiration update ───────────────────────────────────
def update_expired_pickups(cur, conn):
    """Query-time UPDATE on page load: mark scheduled pickups as 'missed' if linked FoodListing expired."""
    try:
        cur.execute(
            """
            UPDATE Pickups p
            JOIN   Claims c ON c.claim_id = p.claim_id
            JOIN   FoodListings fl ON fl.listing_id = c.listing_id
            SET    p.status = 'missed'
            WHERE  p.status = 'scheduled'
              AND  fl.expiry_datetime < NOW()
            """
        )
        conn.commit()
    except Exception:
        if conn:
            conn.rollback()


# ── NGO routes ────────────────────────────────────────────────────────────────
@app.route("/ngo/dashboard")
@role_required("ngo")
def ngo_dashboard():
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        # Query-time update: mark scheduled pickups for expired food as missed
        update_expired_pickups(cur, conn)

        # Call the GetAvailableListings() stored procedure
        cur.callproc("GetAvailableListings")
        listings = []
        for result in cur.stored_results():
            listings = result.fetchall()
    except Exception as e:
        flash(f"Could not load available listings: {e}", "danger")
        listings = []
    finally:
        if conn:
            conn.close()
    return render_template("ngo_dashboard.html", listings=listings)


@app.route("/ngo/claim/<int:listing_id>", methods=["POST"])
@role_required("ngo")
def claim_listing(listing_id):
    ngo_id = session["ngo_id"]
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        # Call the ClaimListing() stored procedure — handles locking & validation
        cur.callproc("ClaimListing", (listing_id, ngo_id))
        conn.commit()
        flash("Listing claimed! Schedule a pickup below.", "success")
        return redirect(url_for("ngo_my_claims"))  # send straight to My Claims
    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        # The SP raises SIGNAL SQLSTATE '45000' — surface its message to the user
        flash(f"Could not claim listing: {e.msg}", "danger")
    except Exception as e:
        if conn:
            conn.rollback()
        flash(f"Unexpected error: {e}", "danger")
    finally:
        if conn:
            conn.close()
    return redirect(url_for("ngo_dashboard"))


@app.route("/ngo/my-claims")
@role_required("ngo")
def ngo_my_claims():
    """Show all claims made by the logged-in NGO, with pickup status."""
    ngo_id = session["ngo_id"]
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)

        # Query-time update: mark scheduled pickups for expired food as missed
        update_expired_pickups(cur, conn)

        cur.execute(
            """
            SELECT
                c.claim_id,
                c.status          AS claim_status,
                c.claimed_at,
                fl.listing_id,
                fl.food_type,
                fl.quantity,
                fl.expiry_datetime,
                fl.status         AS listing_status,
                p.pickup_id,
                p.scheduled_time,
                p.actual_time,
                p.status          AS pickup_status,
                CASE
                    WHEN p.status = 'scheduled' AND p.scheduled_time < NOW() AND fl.expiry_datetime >= NOW() THEN 1
                    ELSE 0
                END               AS is_overdue
            FROM   Claims c
            JOIN   FoodListings fl ON fl.listing_id = c.listing_id
            LEFT JOIN Pickups   p  ON p.claim_id    = c.claim_id
            WHERE  c.ngo_id = %s
            ORDER BY c.claimed_at DESC
            """,
            (ngo_id,),
        )
        claims = cur.fetchall()
    except Exception as e:
        flash(f"Could not load your claims: {e}", "danger")
        claims = []
    finally:
        if conn:
            conn.close()
    return render_template("ngo_my_claims.html", claims=claims)


@app.route("/ngo/schedule-pickup/<int:claim_id>", methods=["GET", "POST"])
@role_required("ngo")
def schedule_pickup(claim_id):
    ngo_id = session["ngo_id"]
    conn = None

    # ── Ownership check: verify this claim belongs to the logged-in NGO ──────
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT c.claim_id, c.ngo_id, c.status AS claim_status,
                   fl.food_type, fl.quantity, fl.expiry_datetime
            FROM   Claims c
            JOIN   FoodListings fl ON fl.listing_id = c.listing_id
            WHERE  c.claim_id = %s
            """,
            (claim_id,),
        )
        claim = cur.fetchone()
    except Exception as e:
        flash(f"Database error: {e}", "danger")
        if conn:
            conn.close()
        return redirect(url_for("ngo_dashboard"))

    if not claim:
        flash("Claim not found.", "danger")
        conn.close()
        return redirect(url_for("ngo_dashboard"))

    # Ownership enforcement — reject if claim belongs to a different NGO
    if claim["ngo_id"] != ngo_id:
        flash("You are not authorised to schedule a pickup for this claim.", "danger")
        conn.close()
        return redirect(url_for("ngo_dashboard"))

    # Check if a pickup already exists for this claim
    cur.execute("SELECT pickup_id FROM Pickups WHERE claim_id = %s", (claim_id,))
    existing_pickup = cur.fetchone()

    if request.method == "POST":
        scheduled_time_str = request.form.get("scheduled_time", "")
        try:
            scheduled_time = datetime.strptime(scheduled_time_str, "%Y-%m-%dT%H:%M")
        except ValueError:
            flash("Invalid date/time format.", "danger")
            conn.close()
            return render_template("schedule_pickup.html", claim=claim, existing_pickup=existing_pickup)

        try:
            if existing_pickup:
                flash("A pickup is already scheduled for this claim.", "warning")
            else:
                cur.execute(
                    """
                    INSERT INTO Pickups (claim_id, scheduled_time, actual_time, status)
                    VALUES (%s, %s, NULL, 'scheduled')
                    """,
                    (claim_id, scheduled_time),
                )
                conn.commit()
                flash("Pickup scheduled successfully!", "success")
            conn.close()
            return redirect(url_for("ngo_my_claims"))
        except Exception as e:
            conn.rollback()
            flash(f"Failed to schedule pickup: {e}", "danger")
        finally:
            conn.close()
        return redirect(url_for("ngo_my_claims"))

    conn.close()
    return render_template("schedule_pickup.html", claim=claim, existing_pickup=existing_pickup)


@app.route("/ngo/complete-pickup/<int:pickup_id>", methods=["POST"])
@role_required("ngo")
def complete_pickup(pickup_id):
    ngo_id = session["ngo_id"]
    new_status = request.form.get("status", "completed").strip().lower()

    if new_status not in ("completed", "missed"):
        flash("Invalid pickup status update.", "danger")
        return redirect(url_for("ngo_my_claims"))

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)

        # Verify pickup belongs to a claim owned by this NGO
        cur.execute(
            """
            SELECT p.pickup_id, p.status, c.ngo_id
            FROM   Pickups p
            JOIN   Claims  c ON c.claim_id = p.claim_id
            WHERE  p.pickup_id = %s
            """,
            (pickup_id,),
        )
        pickup = cur.fetchone()

        if not pickup:
            flash("Pickup not found.", "danger")
            return redirect(url_for("ngo_my_claims"))

        if pickup["ngo_id"] != ngo_id:
            flash("You are not authorised to update this pickup.", "danger")
            return redirect(url_for("ngo_my_claims"))

        if new_status == "completed":
            cur.execute(
                """
                UPDATE Pickups
                SET    status = 'completed',
                       actual_time = NOW()
                WHERE  pickup_id = %s
                """,
                (pickup_id,),
            )
            flash("Pickup marked as completed! Food collected.", "success")
        elif new_status == "missed":
            cur.execute(
                """
                UPDATE Pickups
                SET    status = 'missed',
                       actual_time = NULL
                WHERE  pickup_id = %s
                """,
                (pickup_id,),
            )
            flash("Pickup marked as missed.", "warning")

        conn.commit()
    except Exception as e:
        if conn:
            conn.rollback()
        flash(f"Failed to update pickup status: {e}", "danger")
    finally:
        if conn:
            conn.close()

    return redirect(url_for("ngo_my_claims"))


# ── Admin routes ──────────────────────────────────────────────────────────────
@app.route("/admin/dashboard")
@role_required("admin")
def admin_dashboard():
    conn = None
    data = {}
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)

        # Q1 — Total donations per donor
        cur.execute("""
            SELECT d.donor_id, d.org_name AS donor_name, d.donor_type,
                   COUNT(fl.listing_id)          AS total_listings,
                   COALESCE(SUM(fl.quantity), 0) AS total_quantity_kg
            FROM   Donors d
            LEFT JOIN FoodListings fl ON fl.donor_id = d.donor_id
            GROUP  BY d.donor_id, d.org_name, d.donor_type
            ORDER  BY total_quantity_kg DESC
        """)
        data["donations_per_donor"] = cur.fetchall()

        # Q2 — Most active NGOs
        cur.execute("""
            SELECT n.ngo_id, n.org_name AS ngo_name, n.capacity,
                   COUNT(c.claim_id) AS total_claims,
                   SUM(CASE WHEN c.status='confirmed' THEN 1 ELSE 0 END) AS confirmed_claims,
                   SUM(CASE WHEN c.status='pending'   THEN 1 ELSE 0 END) AS pending_claims
            FROM   NGOs n
            LEFT JOIN Claims c ON c.ngo_id = n.ngo_id
            GROUP  BY n.ngo_id, n.org_name, n.capacity
            ORDER  BY total_claims DESC
        """)
        data["active_ngos"] = cur.fetchall()

        # Q3 — Expired & unclaimed listings
        cur.execute("""
            SELECT fl.listing_id, d.org_name AS donor_name,
                   fl.food_type, fl.quantity,
                   fl.posted_at, fl.expiry_datetime,
                   TIMESTAMPDIFF(HOUR, fl.expiry_datetime, NOW()) AS hours_since_expired
            FROM   FoodListings fl
            JOIN   Donors d ON fl.donor_id = d.donor_id
            WHERE  fl.expiry_datetime < NOW()
              AND  fl.listing_id NOT IN (SELECT listing_id FROM Claims)
            ORDER  BY fl.expiry_datetime DESC
        """)
        data["expired_unclaimed"] = cur.fetchall()

        # Q4 — Average time-to-claim
        cur.execute("""
            SELECT AVG(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS avg_minutes_to_claim,
                   MIN(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS min_minutes_to_claim,
                   MAX(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS max_minutes_to_claim,
                   COUNT(*) AS total_claims_analysed
            FROM   Claims c
            JOIN   FoodListings fl ON fl.listing_id = c.listing_id
        """)
        data["avg_claim_time"] = cur.fetchone()

        # Q5 — All available listings
        cur.execute("""
            SELECT fl.listing_id, d.org_name AS donor_name, d.donor_type,
                   fl.food_type, fl.quantity,
                   fl.posted_at, fl.expiry_datetime,
                   TIMESTAMPDIFF(MINUTE, NOW(), fl.expiry_datetime) AS minutes_until_expiry
            FROM   FoodListings fl
            JOIN   Donors d ON fl.donor_id = d.donor_id
            WHERE  fl.status = 'available'
              AND  fl.expiry_datetime > NOW()
            ORDER  BY fl.expiry_datetime ASC
        """)
        data["available_listings"] = cur.fetchall()

        # Q6 — Pickup completion rate
        cur.execute("""
            SELECT COUNT(*) AS total_pickups,
                   SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) AS completed,
                   SUM(CASE WHEN status='missed'    THEN 1 ELSE 0 END) AS missed,
                   SUM(CASE WHEN status='scheduled' THEN 1 ELSE 0 END) AS scheduled,
                   ROUND(
                       100.0 * SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END)
                             / NULLIF(COUNT(*), 0), 2
                   ) AS completion_rate_pct
            FROM   Pickups
        """)
        data["pickup_stats"] = cur.fetchone()

    except Exception as e:
        flash(f"Analytics error: {e}", "danger")
    finally:
        if conn:
            conn.close()

    return render_template("admin_dashboard.html", data=data)


# ── Dev server entry point ────────────────────────────────────────────────────
if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
