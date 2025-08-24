const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = "https://lhwzjjkujqpbhdfilblg.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxod3pqamt1anFwYmhkZmlsYmxnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5OTU0NDgsImV4cCI6MjA3MTU3MTQ0OH0.iCgGdOi-yBxx-YDQ-M6QKyNU0xzF7MdiYklYOyzcNGQ";

const supabase = createClient(supabaseUrl, supabaseKey);

module.exports = supabase;
