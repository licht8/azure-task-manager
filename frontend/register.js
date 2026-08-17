const registerForm =
    document.getElementById("registerForm");

const usernameInput =
    document.getElementById("username");

const emailInput =
    document.getElementById("email");

const passwordInput =
    document.getElementById("password");

const confirmPasswordInput =
    document.getElementById("confirmPassword");

const message =
    document.getElementById("message");

const registerButton =
    document.getElementById("registerButton");


function showMessage(text, type) {

    message.textContent = text;

    message.className =
        `auth-message ${type}`;
}


registerForm.addEventListener(
    "submit",
    async event => {

        event.preventDefault();


        const username =
            usernameInput.value.trim();

        const email =
            emailInput.value.trim();

        const password =
            passwordInput.value;

        const confirmPassword =
            confirmPasswordInput.value;


        // Validate password

        if (password.length < 8) {

            showMessage(
                "Password must contain at least 8 characters.",
                "error"
            );

            return;
        }


        // Validate passwords

        if (password !== confirmPassword) {

            showMessage(
                "Passwords do not match.",
                "error"
            );

            return;
        }


        registerButton.disabled = true;

        registerButton.textContent =
            "Creating account...";


        showMessage(
            "Creating your account...",
            "success"
        );


        try {

            const response =
                await fetch(
                    "/auth/register",
                    {
                        method: "POST",

                        headers: {
                            "Content-Type":
                                "application/json"
                        },

                        body: JSON.stringify({
                            username,
                            email,
                            password
                        })
                    }
                );


            const data =
                await response.json();


            if (!response.ok) {

                let errorMessage =
                    "Registration failed.";


                if (data.detail) {

                    errorMessage =
                        typeof data.detail === "string"
                            ? data.detail
                            : "Invalid registration data.";
                }


                throw new Error(
                    errorMessage
                );
            }


            showMessage(
                "Account created successfully!",
                "success"
            );


            registerForm.reset();


            setTimeout(
                () => {

                    window.location.href =
                        "/static/login.html";

                },
                1200
            );


        } catch (error) {

            console.error(error);


            showMessage(
                error.message ||
                "Registration failed.",
                "error"
            );


            registerButton.disabled = false;

            registerButton.textContent =
                "Create account";
        }

    }
);