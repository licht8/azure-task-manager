const API_URL = "";


// ============================================================
// Authentication
// ============================================================

const token =
    localStorage.getItem("access_token");


if (!token) {

    window.location.href =
        "/static/login.html";

}


// ============================================================
// DOM
// ============================================================

const profileName =
    document.getElementById("profileName");

const profileAvatar =
    document.getElementById("profileAvatar");

const profileButton =
    document.getElementById("profileButton");

const settingsButton =
    document.getElementById("settingsButton");

const logoutButton =
    document.getElementById("logoutButton");


const currentAvatar =
    document.getElementById("currentAvatar");

const changeAvatarButton =
    document.getElementById(
        "changeAvatarButton"
    );


const usernameInput =
    document.getElementById(
        "usernameInput"
    );

const profileEmail =
    document.getElementById(
        "profileEmail"
    );

const profileAvatarValue =
    document.getElementById(
        "profileAvatarValue"
    );


const profileForm =
    document.getElementById(
        "profileForm"
    );


const saveProfileButton =
    document.getElementById(
        "saveProfileButton"
    );


const profileSuccess =
    document.getElementById(
        "profileSuccess"
    );

const profileError =
    document.getElementById(
        "profileError"
    );


const avatarModal =
    document.getElementById(
        "avatarModal"
    );

const closeAvatarModal =
    document.getElementById(
        "closeAvatarModal"
    );

const cancelAvatarButton =
    document.getElementById(
        "cancelAvatarButton"
    );

const selectAvatarButton =
    document.getElementById(
        "selectAvatarButton"
    );

const avatarGrid =
    document.getElementById(
        "avatarGrid"
    );


// ============================================================
// State
// ============================================================

let currentUser = null;

let savedAvatar =
    "avatar-01";

let selectedAvatar =
    "avatar-01";


// ============================================================
// Available avatars
// ============================================================

const avatars = [

    "avatar-01",
    "avatar-02",
    "avatar-03",
    "avatar-04",
    "avatar-05",
    "avatar-06",
    "avatar-07",
    "avatar-08",
    "avatar-09",
    "avatar-10"

];


// ============================================================
// API
// ============================================================

async function apiFetch(
    url,
    options = {}
) {

    const token =
        localStorage.getItem(
            "access_token"
        );


    if (!token) {

        window.location.href =
            "/static/login.html";

        return null;

    }


    const headers = {

        ...(options.headers || {}),

        "Authorization":
            `Bearer ${token}`

    };


    const response =
        await fetch(
            url,
            {
                ...options,
                headers
            }
        );


    if (response.status === 401) {

        localStorage.removeItem(
            "access_token"
        );

        window.location.href =
            "/static/login.html";

        return null;

    }


    return response;

}


// ============================================================
// Avatar URL
// ============================================================

function getAvatarUrl(
    avatar
) {

    return `/static/avatars/${avatar}.png`;

}


// ============================================================
// Set avatar image
// ============================================================

function setAvatarImage(
    element,
    avatar
) {

    if (!element) {
        return;
    }


    element.innerHTML = "";


    const image =
        document.createElement("img");


    image.src =
        getAvatarUrl(avatar);


    image.alt =
        "Profile avatar";


    image.className =
        "avatar-image";


    image.onerror =
        () => {

            element.innerHTML =
                "<span>U</span>";

        };


    element.appendChild(
        image
    );

}


// ============================================================
// Render avatar grid
// ============================================================

function renderAvatarGrid() {

    avatarGrid.innerHTML = "";


    avatars.forEach(
        avatar => {

            const option =
                document.createElement(
                    "button"
                );


            option.type =
                "button";


            option.className =
                "avatar-option";


            option.dataset.avatar =
                avatar;


            /*
             * Selected state
             */

            if (
                avatar ===
                selectedAvatar
            ) {

                option.classList.add(
                    "selected"
                );

            }


            /*
             * Avatar image
             */

            const image =
                document.createElement(
                    "img"
                );


            image.src =
                getAvatarUrl(
                    avatar
                );


            image.alt =
                avatar;


            image.className =
                "avatar-option-image";


            /*
             * Click
             */

            option.addEventListener(
                "click",
                () => {

                    selectedAvatar =
                        avatar;


                    renderAvatarGrid();

                }
            );


            option.appendChild(
                image
            );


            avatarGrid.appendChild(
                option
            );

        }
    );

}


// ============================================================
// Open avatar modal
// ============================================================

function openAvatarModal() {

    selectedAvatar =
        savedAvatar;


    renderAvatarGrid();


    avatarModal.classList.remove(
        "hidden"
    );

}


// ============================================================
// Close avatar modal
// ============================================================

function closeAvatarSelector() {

    avatarModal.classList.add(
        "hidden"
    );


    /*
     * Do not change saved avatar
     * until user clicks Select avatar.
     */

    selectedAvatar =
        savedAvatar;

}


// ============================================================
// Change avatar button
// ============================================================

changeAvatarButton.addEventListener(
    "click",
    openAvatarModal
);


// ============================================================
// Close buttons
// ============================================================

closeAvatarModal.addEventListener(
    "click",
    closeAvatarSelector
);


cancelAvatarButton.addEventListener(
    "click",
    closeAvatarSelector
);


// ============================================================
// Click outside modal
// ============================================================

avatarModal.addEventListener(
    "click",
    event => {

        if (
            event.target ===
            avatarModal
        ) {

            closeAvatarSelector();

        }

    }
);


// ============================================================
// Select avatar
// ============================================================

selectAvatarButton.addEventListener(
    "click",
    () => {

        savedAvatar =
            selectedAvatar;


        setAvatarImage(
            currentAvatar,
            savedAvatar
        );


        profileAvatarValue.value =
            savedAvatar;


        closeAvatarSelector();

    }
);


// ============================================================
// Messages
// ============================================================

function clearMessages() {

    profileSuccess.classList.add(
        "hidden"
    );

    profileError.classList.add(
        "hidden"
    );


    profileSuccess.textContent =
        "";


    profileError.textContent =
        "";

}


function showSuccess(
    message
) {

    profileError.classList.add(
        "hidden"
    );


    profileSuccess.textContent =
        message;


    profileSuccess.classList.remove(
        "hidden"
    );

}


function showError(
    message
) {

    profileSuccess.classList.add(
        "hidden"
    );


    profileError.textContent =
        message;


    profileError.classList.remove(
        "hidden"
    );

}


// ============================================================
// Load current user
// ============================================================

async function loadCurrentUser() {

    try {

        const response =
            await apiFetch(
                `${API_URL}/auth/me`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {

            throw new Error(
                "Failed to load user"
            );

        }


        const user =
            await response.json();


        currentUser =
            user;


        /*
         * Avatar
         */

        savedAvatar =
            user.avatar ||
            "avatar-01";


        selectedAvatar =
            savedAvatar;


        /*
         * Sidebar
         */

        profileName.textContent =
            user.username ||
            "User";


        setAvatarImage(
            profileAvatar,
            savedAvatar
        );


        /*
         * Profile
         */

        usernameInput.value =
            user.username ||
            "";


        profileEmail.value =
            user.email ||
            "";


        profileAvatarValue.value =
            savedAvatar;


        setAvatarImage(
            currentAvatar,
            savedAvatar
        );


    } catch (error) {

        console.error(
            "Failed to load current user:",
            error
        );


        showError(
            "Failed to load profile."
        );

    }

}


// ============================================================
// Save profile
// ============================================================

profileForm.addEventListener(
    "submit",
    async event => {

        event.preventDefault();


        clearMessages();


        const username =
            usernameInput.value.trim();


        /*
         * Validation
         */

        if (
            username.length < 3
        ) {

            showError(
                "Username must contain at least 3 characters."
            );

            return;

        }


        if (
            username.length > 50
        ) {

            showError(
                "Username must not exceed 50 characters."
            );

            return;

        }


        if (
            !savedAvatar
        ) {

            showError(
                "Please select an avatar."
            );

            return;

        }


        /*
         * Loading
         */

        saveProfileButton.disabled =
            true;


        saveProfileButton.textContent =
            "Saving...";


        try {

            const response =
                await apiFetch(
                    `${API_URL}/auth/profile`,
                    {

                        method: "PUT",

                        headers: {

                            "Content-Type":
                                "application/json"

                        },

                        body:
                            JSON.stringify({

                                username:
                                    username,

                                avatar:
                                    savedAvatar

                            })

                    }
                );


            if (!response) {
                return;
            }


            const data =
                await response.json();


            if (!response.ok) {

                showError(
                    data.detail ||
                    "Failed to update profile."
                );

                return;

            }


            /*
             * Update state
             */

            currentUser =
                data;


            savedAvatar =
                data.avatar ||
                "avatar-01";


            selectedAvatar =
                savedAvatar;


            /*
             * Update sidebar
             */

            profileName.textContent =
                data.username;


            setAvatarImage(
                profileAvatar,
                savedAvatar
            );


            /*
             * Update profile
             */

            usernameInput.value =
                data.username;


            profileEmail.value =
                data.email;


            profileAvatarValue.value =
                savedAvatar;


            setAvatarImage(
                currentAvatar,
                savedAvatar
            );


            showSuccess(
                "Profile updated successfully."
            );


        } catch (error) {

            console.error(
                "Failed to update profile:",
                error
            );


            showError(
                "Unable to connect to the server."
            );


        } finally {

            saveProfileButton.disabled =
                false;


            saveProfileButton.textContent =
                "Save changes";

        }

    }
);


// ============================================================
// Profile navigation
// ============================================================

profileButton.addEventListener(
    "click",
    () => {

        window.location.href =
            "/static/profile.html";

    }
);


// ============================================================
// Settings navigation
// ============================================================

settingsButton.addEventListener(
    "click",
    () => {

        window.location.href =
            "/static/settings.html";

    }
);


// ============================================================
// Logout
// ============================================================

logoutButton.addEventListener(
    "click",
    () => {

        localStorage.removeItem(
            "access_token"
        );


        localStorage.removeItem(
            "edit_task_id"
        );


        window.location.href =
            "/static/login.html";

    }
);


// ============================================================
// Initial load
// ============================================================

loadCurrentUser();