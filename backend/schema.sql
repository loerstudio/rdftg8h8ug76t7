-- Supabase Schema for Trainer App

-- -------------------------------------------------
-- Table for Public Profiles
-- Stores public user data. Linked to auth.users.
-- -------------------------------------------------
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('trainer', 'client')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table to link Trainers and their Clients
-- -------------------------------------------------
CREATE TABLE clients (
  trainer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (trainer_id, client_id)
);

-- -------------------------------------------------
-- Table for the Exercise Library
-- -------------------------------------------------
CREATE TABLE exercises (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL,
  description TEXT,
  video_url TEXT,
  creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Can be null for global exercises
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Training Programs
-- A program is a container for a client's workout plan.
-- -------------------------------------------------
CREATE TABLE training_programs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL,
  description TEXT,
  trainer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Training Days within a Program
-- e.g., "Day A: Push", "Day B: Pull"
-- -------------------------------------------------
CREATE TABLE training_days (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  program_id BIGINT NOT NULL REFERENCES training_programs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  day_order INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Junction Table for Exercises in a Training Day
-- Specifies sets, reps, etc., for an exercise on a given day.
-- -------------------------------------------------
CREATE TABLE program_exercises (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  day_id BIGINT NOT NULL REFERENCES training_days(id) ON DELETE CASCADE,
  exercise_id BIGINT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  sets INT,
  reps TEXT, -- Using TEXT to allow ranges like "8-12"
  rest_period_seconds INT,
  notes TEXT,
  exercise_order INT,
  UNIQUE(day_id, exercise_id, exercise_order)
);

-- -------------------------------------------------
-- Table for the Food Library
-- As requested, only names.
-- -------------------------------------------------
CREATE TABLE food_library (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL UNIQUE,
  creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Can be null for global foods
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Food (Meal) Plans
-- -------------------------------------------------
CREATE TABLE food_plans (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL,
  trainer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Days within a Food Plan
-- e.g., "Monday", "Tuesday"
-- -------------------------------------------------
CREATE TABLE food_days (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  plan_id BIGINT NOT NULL REFERENCES food_plans(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  day_order INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Meals within a Food Day
-- e.g., "Breakfast", "Lunch"
-- -------------------------------------------------
CREATE TABLE meals (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  day_id BIGINT NOT NULL REFERENCES food_days(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  meal_time TIME,
  meal_order INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Junction Table for Food Items in a Meal
-- -------------------------------------------------
CREATE TABLE meal_items (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  meal_id BIGINT NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
  food_id BIGINT NOT NULL REFERENCES food_library(id) ON DELETE CASCADE,
  quantity TEXT, -- e.g., "100g", "1 cup"
  notes TEXT
);

-- -------------------------------------------------
-- Table for Chat Messages
-- -------------------------------------------------
CREATE TABLE chat_messages (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message_text TEXT NOT NULL,
  created_at TIMESTAMTz DEFAULT now()
);

-- -------------------------------------------------
-- Table for Client Progress Photos
-- -------------------------------------------------
CREATE TABLE progress_photos (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL, -- URL from Supabase Storage
  taken_on DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------
-- Table for Live Workout Logs
-- Stores data from a client's workout session.
-- -------------------------------------------------
CREATE TABLE workout_logs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  program_exercise_id BIGINT NOT NULL REFERENCES program_exercises(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  set_number INT NOT NULL,
  reps_completed INT,
  weight_used DECIMAL,
  log_date TIMESTAMPTZ DEFAULT now(),
  UNIQUE(program_exercise_id, client_id, set_number, log_date)
);

-- -------------------------------------------------
-- RLS (Row Level Security) Policies
-- Enable RLS for all tables.
-- -------------------------------------------------
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;

-- Note: Specific RLS policies will be created in a later step
-- to ensure users can only access their own data.
-- For example, a client can only see their own programs,
-- and a trainer can only see their own clients.

-- -------------------------------------------------
-- Function and Trigger to create a profile on new user signup
-- -------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'role'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- -------------------------------------------------
-- RLS Policies for Client Management
-- -------------------------------------------------

-- Policies for 'profiles' table
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Trainers can view their clients' profiles" ON public.profiles;
CREATE POLICY "Trainers can view their clients' profiles" ON public.profiles
  FOR SELECT USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'trainer'
    AND id IN (SELECT client_id FROM public.clients WHERE trainer_id = auth.uid())
  );

-- Policies for 'clients' table
DROP POLICY IF EXISTS "Trainers can manage their own client links" ON public.clients;
CREATE POLICY "Trainers can manage their own client links" ON public.clients
  FOR ALL USING (auth.uid() = trainer_id);

DROP POLICY IF EXISTS "Clients can view their own trainer link" ON public.clients;
CREATE POLICY "Clients can view their own trainer link" ON public.clients
  FOR SELECT USING (auth.uid() = client_id);

-- -------------------------------------------------
-- DB Function to add a client to a trainer
-- -------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_client_by_email(client_email TEXT)
RETURNS JSON AS $$
DECLARE
  client_record RECORD;
BEGIN
  -- Find the user with the given email and 'client' role
  SELECT id, role INTO client_record
  FROM public.profiles
  WHERE email = client_email;

  -- Check if client exists and has the correct role
  IF client_record IS NULL THEN
    RETURN json_build_object('status', 'error', 'message', 'Nessun utente trovato con questa email.');
  END IF;

  IF client_record.role != 'client' THEN
    RETURN json_build_object('status', 'error', 'message', 'L''utente trovato non è un cliente.');
  END IF;

  -- Insert the relationship
  INSERT INTO public.clients (trainer_id, client_id)
  VALUES (auth.uid(), client_record.id);

  RETURN json_build_object('status', 'success', 'message', 'Cliente aggiunto con successo!', 'client_id', client_record.id);
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('status', 'error', 'message', 'Questo cliente è già stato aggiunto.');
  WHEN OTHERS THEN
    RETURN json_build_object('status', 'error', 'message', 'Si è verificato un errore imprevisto.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------
-- RLS Policies for Program Management
-- -------------------------------------------------

-- Policies for 'training_programs' table
DROP POLICY IF EXISTS "Trainers can manage their own programs" ON public.training_programs;
CREATE POLICY "Trainers can manage their own programs" ON public.training_programs
  FOR ALL USING (auth.uid() = trainer_id);

DROP POLICY IF EXISTS "Clients can view their own programs" ON public.training_programs;
CREATE POLICY "Clients can view their own programs" ON public.training_programs
  FOR SELECT USING (auth.uid() = client_id);

-- Policies for 'training_days' table
DROP POLICY IF EXISTS "Users can manage days for accessible programs" ON public.training_days;
CREATE POLICY "Users can manage days for accessible programs" ON public.training_days
  FOR ALL USING (
    program_id IN (SELECT id FROM public.training_programs)
  );

-- Policies for 'program_exercises' table
DROP POLICY IF EXISTS "Users can manage exercises for accessible days" ON public.program_exercises;
CREATE POLICY "Users can manage exercises for accessible days" ON public.program_exercises
  FOR ALL USING (
    day_id IN (SELECT id FROM public.training_days)
  );

-- Policies for 'exercises' (library)
DROP POLICY IF EXISTS "Users can view all exercises" ON public.exercises;
CREATE POLICY "Users can view all exercises" ON public.exercises
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Trainers can add exercises" ON public.exercises;
CREATE POLICY "Trainers can add exercises" ON public.exercises
  FOR INSERT WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'trainer');

-- -------------------------------------------------
-- RLS Policies for Progress Photos
-- -------------------------------------------------
DROP POLICY IF EXISTS "Clients can manage their own photos" ON public.progress_photos;
CREATE POLICY "Clients can manage their own photos" ON public.progress_photos
  FOR ALL USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "Trainers can view their clients' photos" ON public.progress_photos;
CREATE POLICY "Trainers can view their clients' photos" ON public.progress_photos
  FOR SELECT USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'trainer'
    AND client_id IN (SELECT client_id FROM public.clients WHERE trainer_id = auth.uid())
  );

-- -------------------------------------------------
-- DB Function to create a full program in one transaction
-- -------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_full_program(program_name TEXT, program_description TEXT, client_id_in UUID, days JSON)
RETURNS JSON AS $$
DECLARE
  new_program_id BIGINT;
  day_data JSONB;
  exercise_data JSONB;
  new_day_id BIGINT;
BEGIN
  -- Insert the main program
  INSERT INTO public.training_programs (name, description, trainer_id, client_id)
  VALUES (program_name, program_description, auth.uid(), client_id_in)
  RETURNING id INTO new_program_id;

  -- Loop through each day in the JSON array
  FOR day_data IN SELECT * FROM jsonb_array_elements(days::jsonb)
  LOOP
    -- Insert the training day
    INSERT INTO public.training_days (program_id, name, day_order)
    VALUES (new_program_id, day_data->>'name', (day_data->>'day_order')::INT)
    RETURNING id INTO new_day_id;

    -- Loop through each exercise for the current day
    FOR exercise_data IN SELECT * FROM jsonb_array_elements(day_data->'exercises')
    LOOP
      INSERT INTO public.program_exercises (day_id, exercise_id, sets, reps, rest_period_seconds, exercise_order, notes)
      VALUES (
        new_day_id,
        (exercise_data->>'exercise_id')::BIGINT,
        (exercise_data->>'sets')::INT,
        exercise_data->>'reps',
        (exercise_data->>'rest_period_seconds')::INT,
        (exercise_data->>'exercise_order')::INT,
        exercise_data->>'notes'
      );
    END LOOP;
  END LOOP;

  RETURN json_build_object('status', 'success', 'message', 'Program created successfully', 'program_id', new_program_id);
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------
-- RLS Policies for Food Plan Management
-- -------------------------------------------------

-- Policies for 'food_plans' table
DROP POLICY IF EXISTS "Trainers can manage their own food plans" ON public.food_plans;
CREATE POLICY "Trainers can manage their own food plans" ON public.food_plans
  FOR ALL USING (auth.uid() = trainer_id);

DROP POLICY IF EXISTS "Clients can view their own food plans" ON public.food_plans;
CREATE POLICY "Clients can view their own food plans" ON public.food_plans
  FOR SELECT USING (auth.uid() = client_id);

-- Policies for related food tables (cascading access)
DROP POLICY IF EXISTS "Users can access items for accessible food plans" ON public.food_days;
CREATE POLICY "Users can access items for accessible food plans" ON public.food_days
  FOR ALL USING (plan_id IN (SELECT id FROM public.food_plans));

DROP POLICY IF EXISTS "Users can access items for accessible food plans" ON public.meals;
CREATE POLICY "Users can access items for accessible food plans" ON public.meals
  FOR ALL USING (day_id IN (SELECT id FROM public.food_days));

DROP POLICY IF EXISTS "Users can access items for accessible food plans" ON public.meal_items;
CREATE POLICY "Users can access items for accessible food plans" ON public.meal_items
  FOR ALL USING (meal_id IN (SELECT id FROM public.meals));

-- Policies for 'food_library'
DROP POLICY IF EXISTS "Users can view all food items" ON public.food_library;
CREATE POLICY "Users can view all food items" ON public.food_library
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Trainers can add food items" ON public.food_library;
CREATE POLICY "Trainers can add food items" ON public.food_library
  FOR INSERT WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'trainer');

-- -------------------------------------------------
-- RLS Policies and Realtime for Chat
-- -------------------------------------------------
DROP POLICY IF EXISTS "Users can only see their own messages" ON public.chat_messages;
CREATE POLICY "Users can only see their own messages" ON public.chat_messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can only send messages as themselves" ON public.chat_messages;
CREATE POLICY "Users can only send messages as themselves" ON public.chat_messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Enable Realtime for the chat_messages table
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime;
COMMIT;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- -------------------------------------------------
-- RLS Policies for Workout Logs
-- -------------------------------------------------
DROP POLICY IF EXISTS "Clients can insert their own workout logs" ON public.workout_logs;
CREATE POLICY "Clients can insert their own workout logs" ON public.workout_logs
  FOR INSERT WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS "Clients can view their own workout logs" ON public.workout_logs;
CREATE POLICY "Clients can view their own workout logs" ON public.workout_logs
  FOR SELECT USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "Trainers can view their clients' workout logs" ON public.workout_logs;
CREATE POLICY "Trainers can view their clients' workout logs" ON public.workout_logs
  FOR SELECT USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'trainer'
    AND client_id IN (SELECT client_id FROM public.clients WHERE trainer_id = auth.uid())
  );
