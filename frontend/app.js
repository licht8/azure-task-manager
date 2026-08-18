const API_URL = "";


// ============================================================
// Authentication
// ============================================================

const initialToken =
    localStorage.getItem("access_token");

if (!initialToken) {

    window.location.href =
        "/static/login.html";
}


async function apiFetch(url, options = {}) {

    const token =
        localStorage.getItem("access_token");


    if (!token) {

        window.location.href =
            "/static/login.html";

        return null;
    }


    const headers = {
        ...(options.headers || {}),
        "Authorization": `Bearer ${token}`
    };


    const response = await fetch(
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
// DOM
// ============================================================

const taskList =
    document.getElementById("taskList");

const emptyState =
    document.getElementById("emptyState");


const totalTasks =
    document.getElementById("totalTasks");

const pendingTasks =
    document.getElementById("pendingTasks");

const inProgressTasks =
    document.getElementById("inProgressTasks");

const completedTasks =
    document.getElementById("completedTasks");


const searchInput =
    document.getElementById("searchInput");

const statusFilter =
    document.getElementById("statusFilter");

const priorityFilter =
    document.getElementById("priorityFilter");


const newTaskButton =
    document.getElementById("newTaskButton");

const logoutButton =
    document.getElementById("logoutButton");
	
const profileName =
    document.getElementById("profileName");

const profileAvatar =
    document.getElementById("profileAvatar");

const settingsButton =
    document.getElementById("settingsButton");


const taskModal =
    document.getElementById("taskModal");

const closeModal =
    document.getElementById("closeModal");

const cancelButton =
    document.getElementById("cancelButton");


const taskForm =
    document.getElementById("taskForm");


const modalTitle =
    document.getElementById("modalTitle");


const taskTitle =
    document.getElementById("taskTitle");

const taskDescription =
    document.getElementById("taskDescription");

const taskStatus =
    document.getElementById("taskStatus");

const taskPriority =
    document.getElementById("taskPriority");

const taskDueDate =
    document.getElementById("taskDueDate");
	
	


// ============================================================
// State
// ============================================================

let editingTaskId = null;

let searchTimeout = null;


// ============================================================
// Logout
// ============================================================

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


// ============================================================
// Sidebar Avatar
// ============================================================

function getAvatarUrl(avatar) {

    return `/static/avatars/${avatar}.png`;

}


function setSidebarAvatar(avatar) {

    if (!profileAvatar) {
        return;
    }


    profileAvatar.innerHTML = "";


    const image =
        document.createElement("img");


    image.src =
        getAvatarUrl(
            avatar || "avatar-01"
        );


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
                "Failed to load current user"
            );

        }


        const user =
            await response.json();


		const username =
			user.username || "User";


		profileName.textContent =
			username;
	

		setSidebarAvatar(
			user.avatar || "avatar-01"
		);


    } catch (error) {

        console.error(
            "Failed to load current user:",
            error
        );


        profileName.textContent =
            "User";


        profileAvatar.textContent =
            "U";

    }
}

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

settingsButton.addEventListener(
    "click",
    () => {
        window.location.href =
            "/static/settings.html";
    }
);


// ============================================================
// Load tasks
// ============================================================

async function loadTasks() {

    try {

        const params =
            new URLSearchParams();


        const search =
            searchInput.value.trim();

        const status =
            statusFilter.value;

        const priority =
            priorityFilter.value;


        if (search) {
            params.append(
                "search",
                search
            );
        }


        if (status) {
            params.append(
                "status",
                status
            );
        }


        if (priority) {
            params.append(
                "priority",
                priority
            );
        }


        params.append(
            "skip",
            "0"
        );

        params.append(
            "limit",
            "100"
        );


        const response =
            await apiFetch(
                `${API_URL}/tasks?${params.toString()}`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {
            throw new Error(
                "Failed to load tasks"
            );
        }


        const tasks =
            await response.json();


        renderTasks(tasks);


    } catch (error) {

        console.error(error);

        taskList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">!</div>
                <h3>Unable to load tasks</h3>
                <p>Please try again.</p>
            </div>
        `;
    }
}


// ============================================================
// Render tasks
// ============================================================

function renderTasks(tasks) {

    taskList.innerHTML = "";


    if (tasks.length === 0) {

        emptyState.classList.remove(
            "hidden"
        );

        return;
    }


    emptyState.classList.add(
        "hidden"
    );


    tasks.forEach(task => {

        const card =
            document.createElement("div");


        card.className =
            "task-card";


        const dueDate =
            task.due_date
                ? formatDate(task.due_date)
                : null;


        card.innerHTML = `

            <div class="task-top">

                <div>

                    <h3 class="task-title">
                        ${escapeHtml(task.title)}
                    </h3>

                    ${
                        task.description
                            ? `
                                <p class="task-description">
                                    ${escapeHtml(task.description)}
                                </p>
                            `
                            : ""
                    }

                </div>

            </div>


            <div class="task-meta">

                <span class="badge status-${task.status}">
                    ${formatStatus(task.status)}
                </span>

                <span class="badge priority-${task.priority}">
                    ${formatPriority(task.priority)}
                </span>

                ${
                    dueDate
                        ? `
                            <span class="badge">
                                Due ${dueDate}
                            </span>
                        `
                        : ""
                }

            </div>


            <div class="task-actions">

                <button
                    class="edit-button"
                    onclick="openEditTask(${task.id})"
                >
                    Edit
                </button>

                <button
                    class="delete-button"
                    onclick="deleteTask(${task.id})"
                >
                    Delete
                </button>

            </div>

        `;


        taskList.appendChild(card);
    });
}


// ============================================================
// Load statistics
// ============================================================

async function loadStats() {

    try {

        const response =
            await apiFetch(
                `${API_URL}/tasks/stats`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {
            throw new Error(
                "Failed to load statistics"
            );
        }


        const stats =
            await response.json();


        totalTasks.textContent =
            stats.total;

        pendingTasks.textContent =
            stats.pending;

        inProgressTasks.textContent =
            stats.in_progress;

        completedTasks.textContent =
            stats.completed;


    } catch (error) {

        console.error(error);
    }
}


// ============================================================
// Dashboard
// ============================================================

async function loadDashboard() {

    await Promise.all([
        loadTasks(),
        loadStats()
    ]);
}


// ============================================================
// Modal
// ============================================================

function openModal() {

    taskModal.classList.remove(
        "hidden"
    );

    setTimeout(
        () => taskTitle.focus(),
        50
    );
}


function closeTaskModal() {

    taskModal.classList.add(
        "hidden"
    );


    taskForm.reset();


    editingTaskId = null;


    modalTitle.textContent =
        "New Task";


    taskStatus.value =
        "pending";


    taskPriority.value =
        "medium";
}


// ============================================================
// New task
// ============================================================

newTaskButton.addEventListener(
    "click",
    () => {

        closeTaskModal();

        openModal();
    }
);


// ============================================================
// Close modal
// ============================================================

closeModal.addEventListener(
    "click",
    closeTaskModal
);


cancelButton.addEventListener(
    "click",
    closeTaskModal
);


taskModal.addEventListener(
    "click",
    event => {

        if (
            event.target === taskModal
        ) {

            closeTaskModal();
        }
    }
);


document.addEventListener(
    "keydown",
    event => {

        if (
            event.key === "Escape" &&
            !taskModal.classList.contains(
                "hidden"
            )
        ) {

            closeTaskModal();
        }
    }
);


// ============================================================
// Create / update task
// ============================================================

taskForm.addEventListener(
    "submit",
    async event => {

        event.preventDefault();


        const data = {

            title:
                taskTitle.value.trim(),

            description:
                taskDescription.value.trim() ||
                null,

            status:
                taskStatus.value,

            priority:
                taskPriority.value,

            due_date:
                taskDueDate.value
                    ? new Date(
                        taskDueDate.value
                    ).toISOString()
                    : null
        };


        try {

            let response;


            if (
                editingTaskId === null
            ) {

                response =
                    await apiFetch(
                        `${API_URL}/tasks`,
                        {
                            method: "POST",

                            headers: {
                                "Content-Type":
                                    "application/json"
                            },

                            body:
                                JSON.stringify(
                                    data
                                )
                        }
                    );

            } else {

                response =
                    await apiFetch(
                        `${API_URL}/tasks/${editingTaskId}`,
                        {
                            method: "PUT",

                            headers: {
                                "Content-Type":
                                    "application/json"
                            },

                            body:
                                JSON.stringify(
                                    data
                                )
                        }
                    );
            }


            if (!response) {
                return;
            }


            if (!response.ok) {

                const error =
                    await response.json();


                throw new Error(
                    error.detail ||
                    "Failed to save task"
                );
            }


            closeTaskModal();


            await loadDashboard();


        } catch (error) {

            console.error(error);

            alert(error.message);
        }
    }
);


// ============================================================
// Edit task
// ============================================================

async function openEditTask(taskId) {

    try {

        const response =
            await apiFetch(
                `${API_URL}/tasks/${taskId}`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {
            throw new Error(
                "Failed to load task"
            );
        }


        const task =
            await response.json();


        editingTaskId =
            task.id;


        modalTitle.textContent =
            "Edit Task";


        taskTitle.value =
            task.title;


        taskDescription.value =
            task.description || "";


        taskStatus.value =
            task.status;


        taskPriority.value =
            task.priority;


        if (task.due_date) {

            const date =
                new Date(
                    task.due_date
                );


            taskDueDate.value =
                formatDateTimeLocal(
                    date
                );

        } else {

            taskDueDate.value =
                "";
        }


        openModal();


    } catch (error) {

        console.error(error);

        alert(error.message);
    }
}


// ============================================================
// Delete task
// ============================================================

async function deleteTask(taskId) {

    const confirmed =
        confirm(
            "Delete this task?"
        );


    if (!confirmed) {
        return;
    }


    try {

        const response =
            await apiFetch(
                `${API_URL}/tasks/${taskId}`,
                {
                    method: "DELETE"
                }
            );


        if (!response) {
            return;
        }


        if (!response.ok) {

            const error =
                await response.json();


            throw new Error(
                error.detail ||
                "Failed to delete task"
            );
        }


        await loadDashboard();


    } catch (error) {

        console.error(error);

        alert(error.message);
    }
}


// ============================================================
// Search
// ============================================================

searchInput.addEventListener(
    "input",
    () => {

        clearTimeout(
            searchTimeout
        );


        searchTimeout =
            setTimeout(
                () => {
                    loadTasks();
                },
                300
            );
    }
);


// ============================================================
// Filters
// ============================================================

statusFilter.addEventListener(
    "change",
    loadTasks
);


priorityFilter.addEventListener(
    "change",
    loadTasks
);


// ============================================================
// Formatting
// ============================================================

function formatStatus(status) {

    switch (status) {

        case "pending":
            return "Pending";

        case "in_progress":
            return "In Progress";

        case "completed":
            return "Completed";

        default:
            return status;
    }
}


function formatPriority(priority) {

    switch (priority) {

        case "low":
            return "Low";

        case "medium":
            return "Medium";

        case "high":
            return "High";

        default:
            return priority;
    }
}


function formatDate(dateString) {

    return new Date(
        dateString
    ).toLocaleString(
        undefined,
        {
            dateStyle: "medium",
            timeStyle: "short"
        }
    );
}


function formatDateTimeLocal(date) {

    const year =
        date.getFullYear();

    const month =
        String(
            date.getMonth() + 1
        ).padStart(2, "0");

    const day =
        String(
            date.getDate()
        ).padStart(2, "0");

    const hours =
        String(
            date.getHours()
        ).padStart(2, "0");

    const minutes =
        String(
            date.getMinutes()
        ).padStart(2, "0");


    return `${year}-${month}-${day}T${hours}:${minutes}`;
}


// ============================================================
// Security
// ============================================================

function escapeHtml(value) {

    const div =
        document.createElement("div");

    div.textContent =
        value ?? "";

    return div.innerHTML;
}


// ============================================================
// Initial load
// ============================================================

loadCurrentUser();

loadDashboard();