const API_URL = "";


// ============================================================
// Authentication
// ============================================================

function getAccessToken() {

    return localStorage.getItem(
        "access_token"
    );
}


function redirectToLogin() {

    localStorage.removeItem(
        "access_token"
    );

    window.location.href =
        "/static/login.html";
}


async function apiFetch(
    url,
    options = {}
) {

    const token =
        getAccessToken();


    if (!token) {

        redirectToLogin();

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

        redirectToLogin();

        return null;
    }


    return response;
}


// ============================================================
// Initial load
// ============================================================

document.addEventListener(
    "DOMContentLoaded",
    () => {

        loadAnalytics();

        loadProfile();

        setupNavigation();

    }
);


// ============================================================
// Analytics
// ============================================================

async function loadAnalytics() {

    try {

        const response =
            await apiFetch(
                `${API_URL}/analytics`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {

            throw new Error(
                "Failed to load analytics"
            );

        }


        const data =
            await response.json();


        renderStatistics(
            data.statistics
        );


        renderActivity(
            data.activity
        );


    } catch (error) {

        console.error(
            "Analytics error:",
            error
        );


        const activityList =
            document.getElementById(
                "activityList"
            );


        if (activityList) {

            activityList.innerHTML = `
                <div class="activity-empty error">
                    Failed to load analytics.
                </div>
            `;

        }

    }

}


// ============================================================
// Statistics
// ============================================================

function renderStatistics(stats) {

    const total =
        Number(
            stats.total || 0
        );


    document.getElementById(
        "totalTasks"
    ).textContent =
        total;


    document.getElementById(
        "completedTasks"
    ).textContent =
        stats.completed || 0;


    document.getElementById(
        "progressTasks"
    ).textContent =
        stats.in_progress || 0;


    document.getElementById(
        "overdueTasks"
    ).textContent =
        stats.overdue || 0;


    document.getElementById(
        "pendingCount"
    ).textContent =
        stats.pending || 0;


    document.getElementById(
        "inProgressCount"
    ).textContent =
        stats.in_progress || 0;


    document.getElementById(
        "completedCount"
    ).textContent =
        stats.completed || 0;


    document.getElementById(
        "lowPriority"
    ).textContent =
        stats.low_priority || 0;


    document.getElementById(
        "mediumPriority"
    ).textContent =
        stats.medium_priority || 0;


    document.getElementById(
        "highPriority"
    ).textContent =
        stats.high_priority || 0;


    setBarWidth(
        "pendingBar",
        stats.pending,
        total
    );


    setBarWidth(
        "inProgressBar",
        stats.in_progress,
        total
    );


    setBarWidth(
        "completedBar",
        stats.completed,
        total
    );


    setBarWidth(
        "lowBar",
        stats.low_priority,
        total
    );


    setBarWidth(
        "mediumBar",
        stats.medium_priority,
        total
    );


    setBarWidth(
        "highBar",
        stats.high_priority,
        total
    );

}


// ============================================================
// Analytics bars
// ============================================================

function setBarWidth(
    elementId,
    value,
    total
) {

    const element =
        document.getElementById(
            elementId
        );


    if (!element) {
        return;
    }


    if (!total || !value) {

        element.style.width =
            "0%";

        return;
    }


    const percentage =
        Math.min(
            100,
            (
                Number(value) /
                Number(total)
            ) * 100
        );


    element.style.width =
        `${percentage}%`;

}


// ============================================================
// Activity
// ============================================================

function renderActivity(activity) {

    const container =
        document.getElementById(
            "activityList"
        );


    if (!container) {
        return;
    }


    if (
        !activity ||
        activity.length === 0
    ) {

        container.innerHTML = `
            <div class="activity-empty">
                No activity yet.
            </div>
        `;

        return;
    }


    container.innerHTML = "";


    activity.forEach(
        item => {

            const row =
                document.createElement(
                    "div"
                );


            row.className =
                "activity-item";


            const icon =
                document.createElement(
                    "div"
                );


            icon.className =
                `activity-icon ${item.action}`;


            icon.textContent =
                getActivityIcon(
                    item.action
                );


            const content =
                document.createElement(
                    "div"
                );


            content.className =
                "activity-content";


            const description =
                document.createElement(
                    "div"
                );


            description.className =
                "activity-description";


            description.textContent =
                item.description;


            const meta =
                document.createElement(
                    "div"
                );


            meta.className =
                "activity-meta";


            if (
                item.task_id !== null
            ) {

                meta.textContent =
                    `Task #${item.task_id} • ${formatDate(item.created_at)}`;

            } else {

                meta.textContent =
                    formatDate(
                        item.created_at
                    );

            }


            content.appendChild(
                description
            );


            content.appendChild(
                meta
            );


            row.appendChild(
                icon
            );


            row.appendChild(
                content
            );


            container.appendChild(
                row
            );

        }
    );

}


// ============================================================
// Activity icon
// ============================================================

function getActivityIcon(action) {

    switch (action) {

        case "created":
            return "+";

        case "updated":
            return "↻";

        case "deleted":
            return "×";

        default:
            return "•";

    }

}


// ============================================================
// Date formatting
// ============================================================

function formatDate(dateString) {

    const date =
        new Date(
            dateString
        );


    if (
        Number.isNaN(
            date.getTime()
        )
    ) {

        return dateString;

    }


    return date.toLocaleString(
        undefined,
        {
            day: "2-digit",
            month: "short",
            hour: "2-digit",
            minute: "2-digit"
        }
    );

}


// ============================================================
// Profile
// ============================================================

async function loadProfile() {

    try {

        const response =
            await apiFetch(
                `${API_URL}/auth/me`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {
            return;
        }


        const user =
            await response.json();


        const username =
            user.username ||
            "User";


        const avatar =
            username
                .charAt(0)
                .toUpperCase();


        const profileName =
            document.getElementById(
                "profileName"
            );


        const profileAvatar =
            document.getElementById(
                "profileAvatar"
            );


        if (profileName) {

            profileName.textContent =
                username;

        }


        if (profileAvatar) {

            profileAvatar.textContent =
                avatar;

        }

    } catch (error) {

        console.error(
            "Profile error:",
            error
        );

    }

}


// ============================================================
// Navigation
// ============================================================

function setupNavigation() {

    const settingsButton =
        document.getElementById(
            "settingsButton"
        );


    const logoutButton =
        document.getElementById(
            "logoutButton"
        );


    if (settingsButton) {

        settingsButton.addEventListener(
            "click",
            () => {

                window.location.href =
                    "/static/settings.html";

            }
        );

    }


    if (logoutButton) {

        logoutButton.addEventListener(
            "click",
            () => {

                localStorage.removeItem(
                    "access_token"
                );


                window.location.href =
                    "/static/login.html";

            }
        );

    }

}