// -------------------------------------------------
// API Functions for data interaction with Supabase
// -------------------------------------------------

// -------------------------------------------------
// Client Management
// -------------------------------------------------

/**
 * Fetches all clients for the currently logged-in trainer.
 * The RLS policies ensure a trainer can only get their own clients.
 * @returns {Promise<Array|null>} - A promise that resolves to an array of client profiles.
 */
async function getClients() {
    const { data, error } = await supabase
        .from('clients')
        .select(`
            client_id,
            profiles (
                id,
                full_name,
                email
            )
        `);

    if (error) {
        console.error('Error fetching clients:', error.message);
        alert(`Errore nel recupero dei clienti: ${error.message}`);
        return null;
    }

    // The data is nested, so we extract just the profile part.
    return data.map(item => item.profiles);
}

/**
 * Adds a new client to a trainer's list by calling a database function.
 * @param {string} clientEmail - The email of the client to add.
 * @returns {Promise<Object|null>} - A promise that resolves to the result of the operation.
 */
async function addClient(clientEmail) {
    const { data, error } = await supabase.rpc('add_client_by_email', {
        client_email: clientEmail
    });

    if (error) {
        console.error('Error adding client:', error.message);
        alert(`Errore nell'aggiunta del cliente: ${error.message}`);
        return null;
    }

    alert(data.message);
    return data;
}

// -------------------------------------------------
// Library API Functions
// -------------------------------------------------

/**
 * Fetches all exercises from the library.
 * @returns {Promise<Array|null>}
 */
async function getExerciseLibrary() {
    const { data, error } = await supabase
        .from('exercises')
        .select('*')
        .order('name', { ascending: true });

    if (error) {
        console.error('Error fetching exercise library:', error.message);
        return null;
    }
    return data;
}

/**
 * Fetches all food items from the library.
 * @returns {Promise<Array|null>}
 */
async function getFoodLibrary() {
    const { data, error } = await supabase
        .from('food_library')
        .select('*')
        .order('name', { ascending: true });

    if (error) {
        console.error('Error fetching food library:', error.message);
        return null;
    }
    return data;
}

/**
 * Removes a client from a trainer's list.
 * RLS policies ensure a trainer can only remove their own clients.
 * @param {string} clientId - The UUID of the client to remove.
 * @returns {Promise<boolean>} - A promise that resolves to true on success.
 */
async function removeClient(clientId) {
    const trainer = await getUserProfile();
    if (!trainer) {
        alert('Utente non trovato.');
        return false;
    }

    const { error } = await supabase
        .from('clients')
        .delete()
        .eq('trainer_id', trainer.id)
        .eq('client_id', clientId);

    if (error) {
        console.error('Error removing client:', error.message);
        alert(`Errore nella rimozione del cliente: ${error.message}`);
        return false;
    }

    console.log('Client removed successfully');
    return true;
}


// -------------------------------------------------
// Program Management
// -------------------------------------------------

/**
 * Creates a new training program including all its days and exercises.
 * @param {Object} programData - The full program data.
 * @param {string} programData.name - The name of the program.
 * @param {string} programData.description - The description of the program.
 * @param {string} programData.clientId - The UUID of the client this program is for.
 * @param {Array} programData.days - An array of day objects.
 * @returns {Promise<Object|null>}
 */
async function createProgram(programData) {
    const { data, error } = await supabase.rpc('create_full_program', {
        program_name: programData.name,
        program_description: programData.description,
        client_id_in: programData.clientId,
        days: programData.days
    });

    if (error) {
        console.error('Error creating program:', error.message);
        alert(`Errore nella creazione del programma: ${error.message}`);
        return null;
    }

    alert(data.message);
    return data;
}

/**
 * Fetches all programs for the currently logged-in trainer.
 * @returns {Promise<Array|null>}
 */
async function getPrograms() {
    const { data, error } = await supabase
        .from('training_programs')
        .select(`
            id,
            name,
            description,
            created_at,
            profiles (
                full_name
            )
        `)
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching programs:', error.message);
        alert(`Errore nel recupero dei programmi: ${error.message}`);
        return null;
    }
    return data;
}

/**
 * Deletes a training program.
 * Cascade delete should handle deleting days and exercises.
 * @param {number} programId - The ID of the program to delete.
 * @returns {Promise<boolean>}
 */
async function deleteProgram(programId) {
    const { error } = await supabase
        .from('training_programs')
        .delete()
        .eq('id', programId);

    if (error) {
        console.error('Error deleting program:', error.message);
        alert(`Errore nell'eliminazione del programma: ${error.message}`);
        return false;
    }

    console.log('Program deleted successfully');
    return true;
}


// -------------------------------------------------
// Client-Side Data Fetching
// -------------------------------------------------

/**
 * Fetches the assigned workout program for the current client, including days and exercises.
 * @returns {Promise<Object|null>}
 */
async function getAssignedWorkoutProgram() {
    const user = await getCurrentUser();
    if (!user) return null;

    const { data, error } = await supabase
        .from('training_programs')
        .select(`
            *,
            training_days (
                *,
                program_exercises (
                    *,
                    exercises (*)
                )
            )
        `)
        .eq('client_id', user.id)
        .order('day_order', { referencedTable: 'training_days', ascending: true })
        .order('exercise_order', { referencedTable: 'training_days.program_exercises', ascending: true })
        .single(); // Assuming a client has only one program at a time for now.

    if (error && error.code !== 'PGRST116') { // Ignore 'single row not found' error
        console.error('Error fetching assigned program:', error.message);
        alert(`Errore nel recupero del programma: ${error.message}`);
        return null;
    }

    return data;
}

/**
 * Fetches the details of a specific training day.
 * RLS policies ensure a user can only fetch days from their own programs.
 * @param {number} dayId - The ID of the training day.
 * @returns {Promise<Object|null>}
 */
async function getTrainingDay(dayId) {
    const { data, error } = await supabase
        .from('training_days')
        .select(`
            *,
            program_exercises (
                *,
                exercises (*)
            )
        `)
        .eq('id', dayId)
        .order('exercise_order', { referencedTable: 'program_exercises', ascending: true })
        .single();

    if (error) {
        console.error('Error fetching training day:', error);
        alert(`Errore nel recupero del giorno di allenamento: ${error.message}`);
        return null;
    }
    return data;
}

/**
 * Logs a single completed set for a client.
 * RLS policies ensure a client can only log for themselves.
 * @param {Object} logData
 * @param {number} logData.program_exercise_id
 * @param {number} logData.set_number
 * @param {number} logData.reps_completed
 * @param {number} logData.weight_used
 * @returns {Promise<Object|null>}
 */
async function logWorkoutSet(logData) {
    const user = await getCurrentUser();
    if (!user) return null;

    const { data, error } = await supabase
        .from('workout_logs')
        .insert([{
            ...logData,
            client_id: user.id
        }]);

    if (error) {
        console.error('Error logging workout set:', error);
        alert('Impossibile salvare la serie.');
        return null;
    }

    console.log('Set logged successfully:', data);
    return data;
}

/**
 * Fetches the profile of the current client's trainer.
 * @returns {Promise<Object|null>}
 */
async function getMyTrainer() {
    const user = await getCurrentUser();
    if (!user) return null;

    // First find the trainer_id from the clients table
    const { data: clientLink, error: linkError } = await supabase
        .from('clients')
        .select('trainer_id')
        .eq('client_id', user.id)
        .single();

    if (linkError || !clientLink) {
        console.error('Error fetching trainer link:', linkError?.message);
        return null;
    }

    // Now fetch the trainer's profile
    const { data: trainerProfile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', clientLink.trainer_id)
        .single();

    if (profileError) {
        console.error('Error fetching trainer profile:', profileError.message);
        return null;
    }
    return trainerProfile;
}

// -------------------------------------------------
// Progress Photos API Functions
// -------------------------------------------------

/**
 * Uploads a file to the 'progress_photos' bucket in Supabase Storage.
 * @param {File} file The file to upload.
 * @returns {Promise<string|null>} The public URL of the uploaded file.
 */
async function uploadProgressPhoto(file) {
    const user = await getCurrentUser();
    if (!user) return null;

    const fileExt = file.name.split('.').pop();
    const fileName = `${Date.now()}.${fileExt}`;
    const filePath = `${user.id}/${fileName}`;

    const { error: uploadError } = await supabase.storage
        .from('progress_photos')
        .upload(filePath, file);

    if (uploadError) {
        console.error('Error uploading photo:', uploadError);
        alert('Errore nel caricamento della foto.');
        return null;
    }

    const { data } = supabase.storage
        .from('progress_photos')
        .getPublicUrl(filePath);

    return data.publicUrl;
}

/**
 * Saves the metadata of a progress photo to the database.
 * @param {string} photoUrl
 * @param {string} takenOn ISO date string
 * @param {string} notes
 * @returns {Promise<Object|null>}
 */
async function saveProgressPhoto(photoUrl, takenOn, notes = '') {
    const user = await getCurrentUser();
    if (!user) return null;

    const { data, error } = await supabase
        .from('progress_photos')
        .insert([{
            client_id: user.id,
            photo_url: photoUrl,
            taken_on: takenOn,
            notes: notes
        }]);

    if (error) {
        console.error('Error saving photo metadata:', error);
        alert('Errore nel salvataggio dei dati della foto.');
        return null;
    }
    return data;
}

/**
 * Fetches all progress photos for the current user.
 * @returns {Promise<Array|null>}
 */
async function getProgressPhotos() {
    const user = await getCurrentUser();
    if (!user) return null;

    const { data, error } = await supabase
        .from('progress_photos')
        .select('*')
        .eq('client_id', user.id)
        .order('taken_on', { ascending: false });

    if (error) {
        console.error('Error fetching progress photos:', error);
        return null;
    }
    return data;
}

/**
 * Fetches a public profile for any user by their ID.
 * RLS policies should allow this if the user is a trainer's client.
 * @param {string} userId
 * @returns {Promise<Object|null>}
 */
async function getUserProfileById(userId) {
    const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

    if (error) {
        console.error(`Error fetching profile for ${userId}:`, error.message);
        return null;
    }
    return data;
}

// -------------------------------------------------
// Chat API Functions
// -------------------------------------------------

/**
 * Fetches the message history between the current user and another user.
 * @param {string} otherUserId - The UUID of the other user in the conversation.
 * @returns {Promise<Array|null>}
 */
async function getChatMessages(otherUserId) {
    const currentUser = await getCurrentUser();
    if (!currentUser) return null;

    const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .or(`(sender_id.eq.${currentUser.id},receiver_id.eq.${otherUserId}),(sender_id.eq.${otherUserId},receiver_id.eq.${currentUser.id})`)
        .order('created_at', { ascending: true });

    if (error) {
        console.error('Error fetching chat messages:', error);
        return null;
    }
    return data;
}

/**
 * Sends a new chat message.
 * @param {string} receiverId - The UUID of the message recipient.
 * @param {string} messageText - The content of the message.
 * @returns {Promise<Object|null>}
 */
async function sendMessage(receiverId, messageText) {
    const currentUser = await getCurrentUser();
    if (!currentUser) return null;

    const { data, error } = await supabase
        .from('chat_messages')
        .insert([{
            sender_id: currentUser.id,
            receiver_id: receiverId,
            message_text: messageText
        }]);

    if (error) {
        console.error('Error sending message:', error);
        return null;
    }
    return data;
}

/**
 * Subscribes to new messages for the current user.
 * @param {function} onNewMessage - The callback function to execute with the new message payload.
 * @returns {Object} - The Supabase subscription object.
 */
function subscribeToMessages(onNewMessage) {
    const subscription = supabase
        .channel('public:chat_messages')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'chat_messages' }, payload => {
            onNewMessage(payload.new);
        })
        .subscribe();

    return subscription;
}

/**
 * Fetches the assigned food plan for the current client.
 * @returns {Promise<Object|null>}
 */
async function getAssignedFoodPlan() {
    const user = await getCurrentUser();
    if (!user) return null;

    const { data, error } = await supabase
        .from('food_plans')
        .select(`
            *,
            food_days (
                *,
                meals (
                    *,
                    meal_items (
                        *,
                        food_library (*)
                    )
                )
            )
        `)
        .eq('client_id', user.id)
        .order('day_order', { referencedTable: 'food_days', ascending: true })
        .order('meal_order', { referencedTable: 'food_days.meals', ascending: true })
        .single();

    if (error && error.code !== 'PGRST116') { // Ignore 'single row not found' error
        console.error('Error fetching assigned food plan:', error.message);
        alert(`Errore nel recupero del piano alimentare: ${error.message}`);
        return null;
    }

    return data;
}
