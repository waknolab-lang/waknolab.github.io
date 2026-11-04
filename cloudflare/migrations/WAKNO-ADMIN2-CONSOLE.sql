
CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  billing_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS customer_identifiers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('email', 'phone')),
  normalized_value TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_identifier_email
  ON customer_identifiers(normalized_value) WHERE kind = 'email';
CREATE INDEX IF NOT EXISTS idx_customer_identifier_phone
  ON customer_identifiers(normalized_value) WHERE kind = 'phone';
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(display_name COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_customers_updated ON customers(updated_at DESC);

CREATE TABLE IF NOT EXISTS customer_tags (
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (customer_id, tag)
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY NOT NULL,
  order_number TEXT NOT NULL UNIQUE,
  submission_id TEXT NOT NULL UNIQUE,
  order_type TEXT NOT NULL CHECK (order_type IN ('service_quote', 'dtf')),
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('new', 'reviewing', 'quote_sent', 'confirmed', 'in_production', 'completed', 'cancelled')),
  estimate_cents INTEGER CHECK (estimate_cents IS NULL OR estimate_cents >= 0),
  final_cents INTEGER CHECK (final_cents IS NULL OR final_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'RON' CHECK (currency = 'RON'),
  due_at TEXT,
  submitted_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_orders_status_submitted ON orders(status, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_type_submitted ON orders(order_type, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_submitted ON orders(customer_id, submitted_at DESC);

CREATE TABLE IF NOT EXISTS service_order_details (
  order_id TEXT PRIMARY KEY NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  services_json TEXT NOT NULL DEFAULT '[]',
  additional_details TEXT NOT NULL DEFAULT '',
  source_message TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS dtf_order_details (
  order_id TEXT PRIMARY KEY NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  roll_width_cm REAL,
  ordered_length_m REAL,
  quantity INTEGER,
  artwork_links_json TEXT NOT NULL DEFAULT '[]',
  billing_json TEXT NOT NULL DEFAULT '{}',
  observations TEXT NOT NULL DEFAULT '',
  source_message TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS order_events (
  id TEXT PRIMARY KEY NOT NULL,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  actor TEXT NOT NULL,
  event_type TEXT NOT NULL,
  old_value_json TEXT,
  new_value_json TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_order_events_order_created ON order_events(order_id, created_at DESC);

CREATE TABLE IF NOT EXISTS internal_notes (
  id TEXT PRIMARY KEY NOT NULL,
  order_id TEXT REFERENCES orders(id) ON DELETE CASCADE,
  customer_id TEXT REFERENCES customers(id) ON DELETE CASCADE,
  author TEXT NOT NULL,
  note TEXT NOT NULL CHECK (length(note) BETWEEN 1 AND 10000),
  created_at TEXT NOT NULL,
  CHECK ((order_id IS NOT NULL) <> (customer_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_internal_notes_order ON internal_notes(order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_internal_notes_customer ON internal_notes(customer_id, created_at DESC);

CREATE TABLE IF NOT EXISTS email_outbox (
  id TEXT PRIMARY KEY NOT NULL,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  email_kind TEXT NOT NULL CHECK (email_kind IN ('admin_notification', 'customer_confirmation')),
  recipient TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sending', 'sent', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TEXT NOT NULL,
  resend_email_id TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  sent_at TEXT,
  UNIQUE(order_id, email_kind)
);
CREATE INDEX IF NOT EXISTS idx_email_outbox_due ON email_outbox(status, next_attempt_at);

CREATE TABLE IF NOT EXISTS request_rate_limits (
  bucket_key TEXT PRIMARY KEY NOT NULL,
  window_start INTEGER NOT NULL,
  request_count INTEGER NOT NULL CHECK (request_count >= 0)
);
CREATE INDEX IF NOT EXISTS idx_request_rate_limits_window ON request_rate_limits(window_start);

ALTER TABLE email_outbox ADD COLUMN last_attempt_at TEXT;
