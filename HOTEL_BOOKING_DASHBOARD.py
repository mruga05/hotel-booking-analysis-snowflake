import streamlit as st


# =========================================================
# PAGE CONFIGURATION
# =========================================================

st.set_page_config(
    page_title="Hotel Booking Dashboard",
    page_icon="🏨",
    layout="wide"
)


# =========================================================
# SNOWFLAKE CONNECTION
# =========================================================

conn = st.connection("snowflake")
session = conn.session()


# =========================================================
# GOLD TABLE NAMES
# =========================================================

BOOKING_TABLE = "HOTEL_DB.PUBLIC.GOLD_BOOKING_CLEAN"
CITY_TABLE = "HOTEL_DB.PUBLIC.GOLD_AGG_HOTEL_CITY"
MONTHLY_TABLE = "HOTEL_DB.PUBLIC.GOLD_AGG_MONTHLY_BOOKING"


# =========================================================
# LOAD BOOKING DATA
# =========================================================

booking_df = session.sql(f"""
    SELECT
        booking_id,
        hotel_id,
        hotel_city,
        customer_id,
        customer_name,
        customer_email,
        check_in_date,
        check_out_date,
        room_type,
        num_guests,
        total_amount,
        currency,
        booking_status
    FROM {BOOKING_TABLE}
""").to_pandas()


# =========================================================
# LOAD CITY REVENUE
# =========================================================

city_df = session.sql(f"""
    SELECT
        hotel_city,
        total_revenue
    FROM {CITY_TABLE}
    ORDER BY total_revenue DESC
""").to_pandas()


# =========================================================
# LOAD MONTHLY DATA
# =========================================================

monthly_df = session.sql(f"""
    SELECT
        month,
        total_booking,
        total_revenue
    FROM {MONTHLY_TABLE}
    ORDER BY month
""").to_pandas()


# =========================================================
# TITLE
# =========================================================

st.title("🏨 Hotel Booking Analytics Dashboard")

st.write(
    "Hotel booking analysis using Snowflake Gold-layer data."
)


# =========================================================
# KPI CALCULATIONS
# =========================================================

total_bookings = len(booking_df)

total_revenue = booking_df["TOTAL_AMOUNT"].sum()

total_guests = booking_df["NUM_GUESTS"].sum()

average_booking_value = (
    total_revenue / total_bookings
    if total_bookings > 0
    else 0
)


# =========================================================
# KPI CARDS
# =========================================================

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        "Total Bookings",
        f"{total_bookings:,}"
    )

with col2:
    st.metric(
        "Total Revenue",
        f"{total_revenue:,.0f}"
    )

with col3:
    st.metric(
        "Total Guests",
        f"{total_guests:,}"
    )

with col4:
    st.metric(
        "Average Booking Value",
        f"{average_booking_value:,.0f}"
    )


st.divider()


# =========================================================
# MONTHLY REVENUE
# =========================================================

st.subheader("📈 Revenue per Month")

monthly_revenue = monthly_df[
    ["MONTH", "TOTAL_REVENUE"]
].copy()

monthly_revenue = monthly_revenue.set_index("MONTH")

st.line_chart(
    monthly_revenue,
    use_container_width=True
)


# =========================================================
# MONTHLY BOOKINGS
# =========================================================

st.subheader("📈 Bookings per Month")

monthly_bookings = monthly_df[
    ["MONTH", "TOTAL_BOOKING"]
].copy()

monthly_bookings = monthly_bookings.set_index("MONTH")

st.line_chart(
    monthly_bookings,
    use_container_width=True
)


# =========================================================
# CITY + ROOM TYPE
# =========================================================

col1, col2 = st.columns(2)


# =========================================================
# TOP CITIES BY REVENUE
# =========================================================

with col1:

    st.subheader("🏙️ Top Cities by Revenue")

    city_chart = city_df[
        ["HOTEL_CITY", "TOTAL_REVENUE"]
    ].copy()

    city_chart = city_chart.set_index("HOTEL_CITY")

    st.bar_chart(
        city_chart,
        use_container_width=True
    )


# =========================================================
# BOOKINGS BY ROOM TYPE
# =========================================================

with col2:

    st.subheader("🛏️ Bookings by Type")

    type_df = session.sql(f"""
        SELECT
            room_type,
            COUNT(*) AS total_booking
        FROM {BOOKING_TABLE}
        GROUP BY room_type
        ORDER BY total_booking DESC
    """).to_pandas()

    type_chart = type_df[
        ["ROOM_TYPE", "TOTAL_BOOKING"]
    ].copy()

    type_chart = type_chart.set_index("ROOM_TYPE")

    st.bar_chart(
        type_chart,
        use_container_width=True
    )


# =========================================================
# BOOKINGS BY STATUS
# =========================================================

st.subheader("📊 Bookings by Status")

status_df = session.sql(f"""
    SELECT
        booking_status,
        COUNT(*) AS total_booking
    FROM {BOOKING_TABLE}
    GROUP BY booking_status
    ORDER BY total_booking DESC
""").to_pandas()


status_chart = status_df[
    ["BOOKING_STATUS", "TOTAL_BOOKING"]
].copy()

status_chart = status_chart.set_index("BOOKING_STATUS")

st.bar_chart(
    status_chart,
    use_container_width=True
)


# =========================================================
# BOOKING DETAILS
# =========================================================

st.subheader("📋 Booking Details")

st.dataframe(
    booking_df,
    use_container_width=True
)