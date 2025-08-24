// -------------------------------------------------
// Auth Functions
// -------------------------------------------------

/**
 * Signs up a new user.
 * The 'profiles' table should be updated automatically by a trigger.
 */
async function signUp(email, password, fullName, role = 'client') {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
        role: role,
      },
    },
  });

  if (error) {
    console.error('Error signing up:', error.message);
    alert(`Errore durante la registrazione: ${error.message}`);
    return null;
  }

  console.log('Sign up successful, confirmation email sent.');
  alert('Registrazione avvenuta con successo! Controlla la tua email per confermare l\'account.');
  return data.user;
}

/**
 * Gets the user's profile from the 'profiles' table.
 */
async function getUserProfile() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

    if (error) {
        console.error('Error fetching profile:', error.message);
        return null;
    }
    return profile;
}

/**
 * Signs in a user using a one-time password (OTP) sent to their email.
 */
async function signInWithOtp(email) {
  const { data, error } = await supabase.auth.signInWithOtp({
    email: email,
  });
  if (error) {
    console.error('Error sending OTP:', error.message);
    alert(`Error: ${error.message}`);
    return false;
  }
  console.log('OTP sent successfully');
  // Store email for the verification step
  localStorage.setItem('emailForVerification', email);
  alert('Controlla la tua email per il codice di accesso!');
  // Redirect to the OTP verification page
  window.location.href = 'pagina-codcie-otp-di-verifica-autenticazione.html';
  return true;
}

/**
 * Verifies the OTP to complete the login process.
 */
async function verifyOtp(email, token) {
  const { data: { session }, error } = await supabase.auth.verifyOtp({
    email: email,
    token: token,
    type: 'email',
  });

  if (error) {
    console.error('Error verifying OTP:', error.message);
    alert(`Errore nella verifica del codice: ${error.message}`);
    return null;
  }

  console.log('OTP verified, session:', session);

  // Now that we have a session, get the user's profile to determine their role
  const profile = await getUserProfile();

  alert('Accesso effettuato con successo!');

  if (profile && profile.role === 'trainer') {
    window.location.href = 'homepage-trainer.html';
  } else {
    window.location.href = 'homepage-cliente.html';
  }

  return session;
}

/**
 * Signs out the current user.
 */
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) {
    console.error('Error signing out:', error.message);
    return;
  }
  console.log('Signed out successfully');
  // Redirect to the login page after sign out
  window.location.href = 'sezione-login-mail-e-password.html';
}

/**
 * Checks if a user is currently logged in.
 * Redirects to the login page if not.
 * This function should be called at the top of every protected page.
 */
async function checkSession() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    console.log('No active session, redirecting to login.');
    window.location.href = 'sezione-login-mail-e-password.html';
  }
  return session;
}

/**
 * Gets the current user from the session.
 */
async function getCurrentUser() {
    const { data: { user } } = await supabase.auth.getUser();
    return user;
}
