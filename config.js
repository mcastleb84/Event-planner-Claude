// Settings for both pages (index.html = staff app, events.html = public page).
// Supabase dashboard → your barbershop project → Settings → API Keys (or the Connect button).
window.CIGAR_CONFIG = {
  SUPABASE_URL: "https://qbyqkngwhpemrgzvykdd.supabase.co",        // e.g. "https://abcd1234.supabase.co"
  SUPABASE_ANON_KEY: "sb_publishable_tClv93an0Iyq7RjtG4JCFw_7DfAXqp4",   // the publishable (sb_publishable_...) or anon (eyJ...) key. Never a secret key.
  SHOP_NAME: "Cigar Events", // shown at the top of the public page
  // Your Square payment link (the same one the barbershop Pay button uses). Shows as a one-tap
  // "Use my Square link" choice for you (the site owner) when you sell tickets.
  // Email shown on the Privacy and terms page for questions and data requests. Leave "" to hide it.
  CONTACT_EMAIL: "",
  SQUARE_LINK: "https://square.link/u/UiKIIteU"
};

