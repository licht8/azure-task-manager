const API_URL = "";

const loginForm = document.getElementById("loginForm");
const usernameInput = document.getElementById("username");
const passwordInput = document.getElementById("password");

const loginButton = document.getElementById("loginButton");
const loginError = document.getElementById("loginError");


loginForm.addEventListener("submit", async (event) => {

    event.preventDefault();

    const username = usernameInput.value.trim();
    const password = passwordInput.value;

    if (!username || !password) {
        showError("Enter username and password.");
        return;
    }

    loginButton.disabled = true;
    loginButton.textContent = "Signing in...";
    hideError();


    try {

        const formData = new URLSearchParams();

        formData.append("username", username);
        formData.append("password", password);


        const response = await fetch(
            `${API_URL}/auth/login`,
            {
                method: "POST",

                headers: {
                    "Content-Type":
                        "application/x-www-form-urlencoded"
                },

                body: formData
            }
        );


        const data = await response.json();


        if (!response.ok) {

            throw new Error(
                data.detail ||
                "Invalid username or password"
            );
        }


        console.log("Login successful");


        localStorage.setItem(
            "access_token",
            data.access_token
        );


        window.location.href = "/";


    } catch (error) {

        console.error("Login error:", error);

        showError(error.message);

        loginButton.disabled = false;
        loginButton.textContent = "Sign In";
    }

});


function showError(message) {

    loginError.textContent = message;

    loginError.classList.remove("hidden");
}


function hideError() {

    loginError.textContent = "";

    loginError.classList.add("hidden");
}