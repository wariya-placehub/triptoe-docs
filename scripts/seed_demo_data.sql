-- ============================================
-- TripToe Demo Data Seed Script
-- City: Austin, TX
-- Assumes: empty database with tables already created (via db.create_all())
-- Run: psql -U postgres -d triptoe -f seed_demo_data.sql
--   or: railway connect Postgres, then \i seed_demo_data.sql
-- ============================================

BEGIN;

-- ============================================
-- 1. GUIDE + OPERATOR
-- ============================================

INSERT INTO guide.guide (guide_uid, email_address, guide_name, google_user_id, bio, languages, specialties, tip_links, is_active)
VALUES (
  'GUIDE_SEED_001',
  'ben@triptoe.com',
  'Ben Erez',
  NULL,
  'Born and raised in Austin. I''ve been giving walking tours for 5 years, sharing the history, food, and culture of this amazing city.',
  '["English", "Spanish"]',
  '["Walking Tours", "Food Tours", "History"]',
  '[{"platform": "venmo", "url": "https://venmo.com/ben-erez"}, {"platform": "paypal", "url": "https://paypal.me/benerez"}]',
  true
);

INSERT INTO guide.operator (operator_id, operator_name, operator_type, primary_email, is_active)
VALUES (nextval('guide.operator_id_seq'), 'Ben''s Austin Tours', 'solo', 'ben@triptoe.com', true);

INSERT INTO guide.guide_operator_role (guide_uid, operator_id, role, is_primary)
VALUES ('GUIDE_SEED_001', currval('guide.operator_id_seq'), 'owner', true);

-- ============================================
-- 2. TOUR TEMPLATES (4 Austin tours)
-- ============================================

INSERT INTO tour.tour_template (tour_template_id, operator_id, tour_title, duration_minutes, meeting_place, meeting_coordinates, meeting_place_details, tour_description, timezone, is_active) VALUES
(nextval('tour.tour_template_id_seq'), currval('guide.operator_id_seq'),
  'Historic Congress Avenue Walk', 90,
  'Texas State Capitol', POINT(-97.7404, 30.2747),
  'Meet at the south entrance steps, near the large star monument',
  'Explore the heart of Austin from the Capitol building down Congress Avenue. See historic landmarks, learn about Texas politics, and discover hidden stories behind the city''s most iconic street.',
  'America/Chicago', true),

(nextval('tour.tour_template_id_seq'), currval('guide.operator_id_seq'),
  'South Congress Food & Culture Tour', 120,
  'Jo''s Coffee', POINT(-97.7503, 30.2488),
  'Meet at the "I love you so much" mural wall',
  'A delicious walking tour through SoCo! Sample local favorites, visit quirky boutiques, and learn why South Congress is the soul of Austin. Includes 4 food tastings.',
  'America/Chicago', true),

(nextval('tour.tour_template_id_seq'), currval('guide.operator_id_seq'),
  'Lady Bird Lake Sunset Tour', 60,
  'Congress Avenue Bridge', POINT(-97.7445, 30.2612),
  'Meet at the southeast corner of the bridge, near the bat viewing area',
  'Watch 1.5 million bats emerge at sunset from the Congress Avenue Bridge while learning about Austin''s ecology and the Lady Bird Lake trail system. Perfect for nature lovers and photographers.',
  'America/Chicago', true),

(nextval('tour.tour_template_id_seq'), currval('guide.operator_id_seq'),
  'East Austin Street Art & Murals', 75,
  'Graffiti Park at Castle Hills', POINT(-97.7256, 30.2935),
  'Meet at the parking lot entrance on 11th Street',
  'Discover Austin''s vibrant street art scene on the East Side. Visit famous murals, meet local artists, and learn the stories behind the most photographed walls in the city.',
  'America/Chicago', true);

-- Save the first tour_template_id for sessions
-- (currval will be the last one inserted; we need the first one)
-- The first template ID is currval - 3

-- ============================================
-- 3. TOUR SESSIONS (for Historic Congress Avenue Walk)
-- ============================================

-- Get the first template ID
DO $$
DECLARE
  first_template_id INTEGER;
  session_id_1 INTEGER;
  session_id_2 INTEGER;
BEGIN
  SELECT currval('tour.tour_template_id_seq') - 3 INTO first_template_id;

  -- Session 1: upcoming (tomorrow 9 AM CDT)
  INSERT INTO tour.tour_session (tour_session_id, tour_template_id, guide_uid, start_at, end_at, allow_guest_messages, is_active)
  VALUES (nextval('tour.tour_session_id_seq'), first_template_id, 'GUIDE_SEED_001',
    (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '14 hours')::timestamptz,  -- 9 AM CDT = 14:00 UTC
    (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '15 hours 30 minutes')::timestamptz,
    true, true)
  RETURNING tour_session_id INTO session_id_1;

  -- Session 2: completed (yesterday 9 AM CDT)
  INSERT INTO tour.tour_session (tour_session_id, tour_template_id, guide_uid, start_at, end_at, allow_guest_messages, is_active)
  VALUES (nextval('tour.tour_session_id_seq'), first_template_id, 'GUIDE_SEED_001',
    (CURRENT_DATE - INTERVAL '1 day' + INTERVAL '14 hours')::timestamptz,
    (CURRENT_DATE - INTERVAL '1 day' + INTERVAL '15 hours 30 minutes')::timestamptz,
    true, true)
  RETURNING tour_session_id INTO session_id_2;

  -- More upcoming sessions (next 3 days at 9 AM CDT)
  INSERT INTO tour.tour_session (tour_session_id, tour_template_id, guide_uid, start_at, end_at, allow_guest_messages, is_active) VALUES
  (nextval('tour.tour_session_id_seq'), first_template_id, 'GUIDE_SEED_001',
    (CURRENT_DATE + INTERVAL '2 days' + INTERVAL '14 hours')::timestamptz,
    (CURRENT_DATE + INTERVAL '2 days' + INTERVAL '15 hours 30 minutes')::timestamptz,
    true, true),
  (nextval('tour.tour_session_id_seq'), first_template_id, 'GUIDE_SEED_001',
    (CURRENT_DATE + INTERVAL '3 days' + INTERVAL '14 hours')::timestamptz,
    (CURRENT_DATE + INTERVAL '3 days' + INTERVAL '15 hours 30 minutes')::timestamptz,
    true, true);

  -- ============================================
  -- 4. GUESTS
  -- ============================================

  INSERT INTO guest.guest (guest_uid, email_address, guest_name, account_status, email_verified) VALUES
  ('GUEST_SEED_001', 'emma.wilson@example.com', 'Emma Wilson', 'verified', true),
  ('GUEST_SEED_002', 'carlos.mendez@example.com', 'Carlos Mendez', 'verified', true),
  ('GUEST_SEED_003', 'yuki.tanaka@example.com', 'Yuki Tanaka', 'verified', true),
  ('GUEST_SEED_004', 'sarah.johnson@example.com', 'Sarah Johnson', 'verified', true),
  ('GUEST_SEED_005', 'liam.oreilly@example.com', 'Liam O''Reilly', 'verified', true);

  -- ============================================
  -- 5. BOOKINGS (5 guests on upcoming session)
  -- ============================================

  INSERT INTO tour.tour_booking (tour_booking_id, tour_session_id, guest_uid) VALUES
  (nextval('tour.tour_booking_id_seq'), session_id_1, 'GUEST_SEED_001'),
  (nextval('tour.tour_booking_id_seq'), session_id_1, 'GUEST_SEED_002'),
  (nextval('tour.tour_booking_id_seq'), session_id_1, 'GUEST_SEED_003'),
  (nextval('tour.tour_booking_id_seq'), session_id_1, 'GUEST_SEED_004'),
  (nextval('tour.tour_booking_id_seq'), session_id_1, 'GUEST_SEED_005');

  -- ============================================
  -- 6. CHECK-INS (3 of 5 guests on upcoming session)
  -- ============================================

  INSERT INTO tour.tour_checkin (tour_checkin_id, tour_session_id, guest_uid, tour_booking_id, location_sharing_enabled, checkin_at) VALUES
  (nextval('tour.tour_checkin_id_seq'), session_id_1, 'GUEST_SEED_001',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_001' AND tour_session_id = session_id_1),
    true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '13 hours 45 minutes')::timestamptz),
  (nextval('tour.tour_checkin_id_seq'), session_id_1, 'GUEST_SEED_002',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_002' AND tour_session_id = session_id_1),
    true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '13 hours 52 minutes')::timestamptz),
  (nextval('tour.tour_checkin_id_seq'), session_id_1, 'GUEST_SEED_003',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_003' AND tour_session_id = session_id_1),
    true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '13 hours 58 minutes')::timestamptz);

  -- ============================================
  -- 7. GUEST LOCATIONS (3 checked-in guests near Capitol)
  -- ============================================

  INSERT INTO guest.guest_location (location_id, guest_uid, tour_session_id, tour_checkin_id, latitude, longitude, accuracy, location_consent, recorded_at) VALUES
  (nextval('guest.guest_location_id_seq'), 'GUEST_SEED_001', session_id_1,
    (SELECT tour_checkin_id FROM tour.tour_checkin WHERE guest_uid = 'GUEST_SEED_001' AND tour_session_id = session_id_1),
    30.2741, -97.7403, 8.0, true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '14 hours 15 minutes')::timestamptz),
  (nextval('guest.guest_location_id_seq'), 'GUEST_SEED_002', session_id_1,
    (SELECT tour_checkin_id FROM tour.tour_checkin WHERE guest_uid = 'GUEST_SEED_002' AND tour_session_id = session_id_1),
    30.2720, -97.7406, 5.0, true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '14 hours 15 minutes')::timestamptz),
  (nextval('guest.guest_location_id_seq'), 'GUEST_SEED_003', session_id_1,
    (SELECT tour_checkin_id FROM tour.tour_checkin WHERE guest_uid = 'GUEST_SEED_003' AND tour_session_id = session_id_1),
    30.2735, -97.7420, 12.0, true, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '14 hours 15 minutes')::timestamptz);

  -- ============================================
  -- 8. GUIDE LOCATION (at Capitol steps)
  -- ============================================

  INSERT INTO guide.guide_location (location_id, guide_uid, tour_session_id, latitude, longitude, accuracy, recorded_at)
  VALUES (nextval('guide.guide_location_id_seq'), 'GUIDE_SEED_001', session_id_1,
    30.2744, -97.7405, 5.0, (CURRENT_DATE + INTERVAL '1 day' + INTERVAL '14 hours 15 minutes')::timestamptz);

  -- ============================================
  -- 9. BOOKINGS + REVIEWS for completed session
  -- ============================================

  INSERT INTO tour.tour_booking (tour_booking_id, tour_session_id, guest_uid) VALUES
  (nextval('tour.tour_booking_id_seq'), session_id_2, 'GUEST_SEED_001'),
  (nextval('tour.tour_booking_id_seq'), session_id_2, 'GUEST_SEED_002'),
  (nextval('tour.tour_booking_id_seq'), session_id_2, 'GUEST_SEED_003');

  INSERT INTO tour.tour_checkin (tour_checkin_id, tour_session_id, guest_uid, tour_booking_id, location_sharing_enabled, checkin_at) VALUES
  (nextval('tour.tour_checkin_id_seq'), session_id_2, 'GUEST_SEED_001',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_001' AND tour_session_id = session_id_2),
    false, (CURRENT_DATE - INTERVAL '1 day' + INTERVAL '13 hours 50 minutes')::timestamptz),
  (nextval('tour.tour_checkin_id_seq'), session_id_2, 'GUEST_SEED_002',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_002' AND tour_session_id = session_id_2),
    false, (CURRENT_DATE - INTERVAL '1 day' + INTERVAL '13 hours 55 minutes')::timestamptz),
  (nextval('tour.tour_checkin_id_seq'), session_id_2, 'GUEST_SEED_003',
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_003' AND tour_session_id = session_id_2),
    false, (CURRENT_DATE - INTERVAL '1 day' + INTERVAL '13 hours 58 minutes')::timestamptz);

  INSERT INTO tour.tour_review (tour_review_id, tour_booking_id, tour_session_id, guest_uid, rating, review_text) VALUES
  (nextval('tour.tour_review_id_seq'),
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_001' AND tour_session_id = session_id_2),
    session_id_2, 'GUEST_SEED_001', 5,
    'Amazing tour! Ben really knows Austin inside and out. The stories about Congress Avenue were fascinating.'),
  (nextval('tour.tour_review_id_seq'),
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_002' AND tour_session_id = session_id_2),
    session_id_2, 'GUEST_SEED_002', 4,
    'Great experience. Learned so much about Texas history. Would recommend!'),
  (nextval('tour.tour_review_id_seq'),
    (SELECT tour_booking_id FROM tour.tour_booking WHERE guest_uid = 'GUEST_SEED_003' AND tour_session_id = session_id_2),
    session_id_2, 'GUEST_SEED_003', 5,
    'Ben is an excellent guide. The pace was perfect and the Capitol building tour was a highlight.');

END $$;

-- ============================================
-- 10. QUICK MESSAGES (outside DO block - no sequence needed)
-- ============================================

INSERT INTO message.quick_message (guide_uid, quick_message_name, content, created_at) VALUES
('GUIDE_SEED_001', 'Welcome', 'Welcome to the tour! We''ll begin shortly. Please stay close to the group.', NOW()),
('GUIDE_SEED_001', 'Next Stop', 'We''re moving to the next stop. Please follow me and watch for traffic.', NOW()),
('GUIDE_SEED_001', 'Photo Op', 'Great photo opportunity here! Take a few minutes to snap some pictures.', NOW()),
('GUIDE_SEED_001', 'Break Time', 'We''ll take a 10-minute break here. Restrooms are to the left. Meet back at this spot.', NOW()),
('GUIDE_SEED_001', 'Tour Ending', 'Thank you for joining today! Please leave a review and check out my local picks in the app.', NOW());

-- ============================================
-- 11. GUIDE'S PICKS (Austin recommendations)
-- ============================================

INSERT INTO guide.guide_pick (guide_pick_id, guide_uid, place_name, category, note, map_link, display_order) VALUES
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Franklin Barbecue', 'eat', 'Best brisket in Texas. Get there early — the line is long but worth it.', 'https://maps.app.goo.gl/franklin', 1),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Torchy''s Tacos', 'eat', 'Try the Trailer Park — trashy style. Multiple locations around Austin.', 'https://maps.app.goo.gl/torchys', 2),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Rainey Street', 'drink', 'A whole street of bars in converted bungalows. Great vibe on weekend nights.', 'https://maps.app.goo.gl/rainey', 3),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Mozart''s Coffee Roasters', 'drink', 'Best coffee with a view of Lake Austin. Try the iced latte.', 'https://maps.app.goo.gl/mozarts', 4),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Barton Springs Pool', 'see', 'Natural spring-fed pool right in the city. 68°F year-round. Bring a towel.', 'https://maps.app.goo.gl/bartonsprings', 5),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Mount Bonnell', 'see', '102 steps to the best panoramic view of Austin and Lake Austin.', 'https://maps.app.goo.gl/mtbonnell', 6),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'South Congress Vintage Shops', 'shop', 'Uncommon Objects and Feathers are must-visits for unique souvenirs.', 'https://maps.app.goo.gl/soco', 7),
(nextval('guide.guide_pick_id_seq'), 'GUIDE_SEED_001', 'Kayak on Lady Bird Lake', 'do', 'Rent a kayak at the Rowing Dock. Sunset paddle is magical.', 'https://maps.app.goo.gl/rowingdock', 8);

COMMIT;

-- ============================================
-- NOTES:
-- - Guide UID: GUIDE_SEED_001 (not linked to Google OAuth — sign in won't work)
-- - To use with a real guide account, replace GUIDE_SEED_001 with the actual guide_uid
--   from guide.guide table after signing in with Google
-- - Session dates are relative to CURRENT_DATE so they stay relevant
-- - The guide has no profile photo or cover images — upload via the app
-- ============================================
