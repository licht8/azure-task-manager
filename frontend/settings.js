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

const settingsButton =
    document.getElementById("settingsButton");

const logoutButton =
    document.getElementById("logoutButton");


const settingsAvatar =
    document.getElementById("settingsAvatar");

const settingsUsername =
    document.getElementById("settingsUsername");

const settingsEmail =
    document.getElementById("settingsEmail");

const settingsRole =
    document.getElementById("settingsRole");


const passwordForm =
    document.getElementById("passwordForm");

const currentPassword =
    document.getElementById("currentPassword");

const newPassword =
    document.getElementById("newPassword");

const confirmPassword =
    document.getElementById("confirmPassword");

const changePasswordButton =
    document.getElementById(
        "changePasswordButton"
    );

const passwordSuccess =
    document.getElementById(
        "passwordSuccess"
    );

const passwordError =
    document.getElementById(
        "passwordError"
    );


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


        const username =
            user.username || "User";


        const email =
            user.email || "Not specified";


        const role =
            user.role || "User";


        const avatar =
            user.avatar || "avatar-01";


        // ====================================================
        // Sidebar username
        // ====================================================

        if (profileName) {

            profileName.textContent =
                username;

        }


        // ====================================================
        // Sidebar avatar
        // ====================================================

        if (profileAvatar) {

            profileAvatar.innerHTML =
                "";


            const image =
                document.createElement(
                    "img"
                );


            image.src =
                `/static/avatars/${avatar}.png`;


            image.alt =
                "Profile avatar";


            image.className =
                "avatar-image";


            image.onerror =
                () => {

                    profileAvatar.innerHTML =
                        "<span>U</span>";

                };


            profileAvatar.appendChild(
                image
            );

        }


        // ====================================================
        // Settings information
        // ====================================================

        if (settingsUsername) {

            settingsUsername.textContent =
                username;

        }


        if (settingsEmail) {

            settingsEmail.textContent =
                email;

        }


        if (settingsRole) {

            settingsRole.textContent =
                role;

        }


        // ====================================================
        // Large Settings avatar
        // ====================================================

        if (settingsAvatar) {

            settingsAvatar.innerHTML =
                "";


            const image =
                document.createElement(
                    "img"
                );


            image.src =
                `/static/avatars/${avatar}.png`;


            image.alt =
                "Profile avatar";


            image.className =
                "avatar-image";


            image.onerror =
                () => {

                    settingsAvatar.innerHTML =
                        "<span>U</span>";

                };


            settingsAvatar.appendChild(
                image
            );

        }


    } catch (error) {

        console.error(
            "Failed to load current user:",
            error
        );


        if (profileName) {

            profileName.textContent =
                "User";

        }


        if (settingsUsername) {

            settingsUsername.textContent =
                "User";

        }

    }

}


// ============================================================
// Password messages
// ============================================================

function clearMessages() {

    passwordSuccess.classList.add(
        "hidden"
    );

    passwordError.classList.add(
        "hidden"
    );

    passwordError.textContent =
        "";

}


function showError(message) {

    passwordSuccess.classList.add(
        "hidden"
    );

    passwordError.textContent =
        message;

    passwordError.classList.remove(
        "hidden"
    );

}


function showSuccess() {

    passwordError.classList.add(
        "hidden"
    );

    passwordSuccess.classList.remove(
        "hidden"
    );

}


// ============================================================
// Change password
// ============================================================

passwordForm.addEventListener(
    "submit",
    async event => {

        event.preventDefault();


        clearMessages();


        const current =
            currentPassword.value.trim();


        const newPasswordValue =
            newPassword.value;


        const confirm =
            confirmPassword.value;


        /*
         * Validation
         */

        if (
            newPasswordValue.length < 6
        ) {

            showError(
                "New password must contain at least 6 characters."
            );

            return;

        }


        if (
            newPasswordValue !== confirm
        ) {

            showError(
                "New passwords do not match."
            );

            return;

        }


        /*
         * Loading state
         */

        changePasswordButton.disabled =
            true;

        changePasswordButton.textContent =
            "Changing...";


        try {

            const response =
                await apiFetch(
                    `${API_URL}/auth/change-password`,
                    {
                        method: "POST",

                        headers: {
                            "Content-Type":
                                "application/json"
                        },

                        body:
                            JSON.stringify({

                                current_password:
                                    current,

                                new_password:
                                    newPasswordValue

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
                    "Failed to change password."
                );

                return;

            }


            /*
             * Success
             */

            showSuccess();


            passwordForm.reset();


        } catch (error) {

            console.error(error);


            showError(
                "Unable to connect to the server."
            );


        } finally {

            changePasswordButton.disabled =
                false;

            changePasswordButton.textContent =
                "Change password";

        }

    }
);


// ============================================================
// Settings
// ============================================================

settingsButton.addEventListener(
    "click",
    () => {

        /*
         * Already on Settings.
         */

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
