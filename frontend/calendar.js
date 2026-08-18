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

const calendarGrid =
    document.getElementById("calendarGrid");

const calendarMonth =
    document.getElementById("calendarMonth");

const calendarSubtitle =
    document.getElementById("calendarSubtitle");

const previousMonth =
    document.getElementById("previousMonth");

const nextMonth =
    document.getElementById("nextMonth");

const todayButton =
    document.getElementById("todayButton");

const logoutButton =
    document.getElementById("logoutButton");
	
const profileName =
    document.getElementById("profileName");

const profileAvatar =
    document.getElementById("profileAvatar");

const settingsButton =
    document.getElementById("settingsButton");
	
const taskDetailsModal =
    document.getElementById("taskDetailsModal");

const closeTaskDetails =
    document.getElementById("closeTaskDetails");

const detailsTaskTitle =
    document.getElementById("detailsTaskTitle");

const detailsTaskDescription =
    document.getElementById("detailsTaskDescription");

const detailsTaskStatus =
    document.getElementById("detailsTaskStatus");

const detailsTaskPriority =
    document.getElementById("detailsTaskPriority");

const detailsTaskDueDate =
    document.getElementById("detailsTaskDueDate");

const editTaskButton =
    document.getElementById("editTaskButton");

const deleteTaskButton =
    document.getElementById("deleteTaskButton");


// ============================================================
// State
// ============================================================

let currentDate =
    new Date();

let tasks = [];


// ============================================================
// API
// ============================================================

async function apiFetch(
    url,
    options = {}
) {

    const token =
        localStorage.getItem("access_token");


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


        /*
         * Username
         */

        profileName.textContent =
            username;


        /*
         * Avatar
         */

        profileAvatar.innerHTML = "";


        const image =
            document.createElement("img");


        image.src =
            `/static/avatars/${user.avatar || "avatar-01"}.png`;


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


    } catch (error) {

        console.error(
            "Failed to load current user:",
            error
        );


        profileName.textContent =
            "User";


        profileAvatar.innerHTML =
            "<span>U</span>";

    }

}

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

        const response =
            await apiFetch(
                `${API_URL}/tasks?skip=0&limit=100`
            );


        if (!response) {
            return;
        }


        if (!response.ok) {

            throw new Error(
                "Failed to load tasks"
            );

        }


        tasks =
            await response.json();


        renderCalendar();

    } catch (error) {

        console.error(error);

        calendarGrid.innerHTML = `

            <div class="calendar-error">

                Failed to load tasks.

            </div>

        `;

    }
}


// ============================================================
// Render calendar
// ============================================================

function renderCalendar() {

    calendarGrid.innerHTML = "";


    const year =
        currentDate.getFullYear();

    const month =
        currentDate.getMonth();


    const monthName =
        currentDate.toLocaleString(
            "en-US",
            {
                month: "long"
            }
        );


    calendarMonth.textContent =
        `${monthName} ${year}`;


    calendarSubtitle.textContent =
        `${getMonthTaskCount(year, month)} scheduled task(s)`;


    /*
     * JavaScript:
     *
     * Sunday = 0
     * Monday = 1
     *
     * We want Monday as first day.
     */

    const firstDay =
        new Date(
            year,
            month,
            1
        ).getDay();


    const mondayOffset =
        firstDay === 0
            ? 6
            : firstDay - 1;


    const daysInMonth =
        new Date(
            year,
            month + 1,
            0
        ).getDate();


    /*
     * Previous month's days
     */

    const previousMonthDays =
        new Date(
            year,
            month,
            0
        ).getDate();


    for (
        let i = mondayOffset - 1;
        i >= 0;
        i--
    ) {

        const day =
            previousMonthDays - i;


        const cell =
            createDayCell(
                day,
                true,
                new Date(
                    year,
                    month - 1,
                    day
                )
            );


        calendarGrid.appendChild(cell);

    }


    /*
     * Current month
     */

    for (
        let day = 1;
        day <= daysInMonth;
        day++
    ) {

        const date =
            new Date(
                year,
                month,
                day
            );


        const cell =
            createDayCell(
                day,
                false,
                date
            );


        calendarGrid.appendChild(cell);

    }


    /*
     * Next month
     */

    const totalCells =
        calendarGrid.children.length;


    const remaining =
        42 - totalCells;


    for (
        let day = 1;
        day <= remaining;
        day++
    ) {

        const cell =
            createDayCell(
                day,
                true,
                new Date(
                    year,
                    month + 1,
                    day
                )
            );


        calendarGrid.appendChild(cell);

    }

}


// ============================================================
// Create day cell
// ============================================================

function createDayCell(
    day,
    outsideMonth,
    date
) {

    const cell =
        document.createElement("div");


    cell.className =
        "calendar-day";


    if (outsideMonth) {

        cell.classList.add(
            "outside-month"
        );

    }


    /*
     * Today
     */

    if (isToday(date)) {

        cell.classList.add(
            "today"
        );

    }


    /*
     * Header
     */

    const header =
        document.createElement("div");


    header.className =
        "calendar-day-header";


    const number =
        document.createElement("span");


    number.className =
        "calendar-day-number";


    number.textContent =
        day;


    header.appendChild(number);

    cell.appendChild(header);


    /*
     * Tasks
     */

    const dayTasks =
        getTasksForDate(date);


    dayTasks.forEach(
        task => {

            const taskElement =
                createTaskElement(task);


            cell.appendChild(
                taskElement
            );

        }
    );


    return cell;

}


// ============================================================
// Get tasks for date
// ============================================================

function getTasksForDate(date) {

    return tasks.filter(
        task => {

            if (!task.due_date) {
                return false;
            }


            const taskDate =
                new Date(
                    task.due_date
                );


            return (
                taskDate.getFullYear() ===
                    date.getFullYear()

                &&

                taskDate.getMonth() ===
                    date.getMonth()

                &&

                taskDate.getDate() ===
                    date.getDate()
            );

        }
    );

}


// ============================================================
// Create task element
// ============================================================

function createTaskElement(task) {

    const element =
        document.createElement("button");


    element.type =
        "button";


    element.className =
        "calendar-task";


    /*
     * Status class
     */

    element.classList.add(
        `calendar-task-${task.status}`
    );


    /*
     * Title
     */

    const title =
        document.createElement("span");


    title.className =
        "calendar-task-title";


    title.textContent =
        task.title;


    element.appendChild(
        title
    );


    /*
     * Time
     */

    if (task.due_date) {

        const time =
            document.createElement("span");


        time.className =
            "calendar-task-time";


        time.textContent =
            formatTime(
                task.due_date
            );


        element.appendChild(
            time
        );

    }


    /*
     * Click
     */

    element.addEventListener(
        "click",
        () => {

            openTask(task);

        }
    );


    return element;

}


// ============================================================
// Open task
// ============================================================

function openTask(task) {

    console.log("Opening task:", task);


    if (!taskDetailsModal) {

        console.error(
            "taskDetailsModal not found"
        );

        return;

    }


    detailsTaskTitle.textContent =
        task.title || "Untitled task";


    detailsTaskDescription.textContent =
        task.description ||
        "No description";


    detailsTaskStatus.textContent =
        formatStatus(task.status);


    detailsTaskPriority.textContent =
        formatPriority(task.priority);


    detailsTaskDueDate.textContent =
        task.due_date
            ? formatDateTime(task.due_date)
            : "No due date";


    taskDetailsModal.dataset.taskId =
        task.id;


    taskDetailsModal.classList.remove(
        "hidden"
    );

}


closeTaskDetails.addEventListener(
    "click",
    () => {

        taskDetailsModal.classList.add(
            "hidden"
        );

    }
);


taskDetailsModal.addEventListener(
    "click",
    event => {

        if (
            event.target ===
            taskDetailsModal
        ) {

            taskDetailsModal.classList.add(
                "hidden"
            );

        }

    }
);


function closeTaskDetailsModal() {

    taskDetailsModal.classList.add(
        "hidden"
    );

}



document.addEventListener(
    "keydown",
    event => {

        if (
            event.key === "Escape" &&
            !taskDetailsModal.classList.contains(
                "hidden"
            )
        ) {

            closeTaskDetailsModal();

        }

    }
);


editTaskButton.addEventListener(
    "click",
    () => {

        const taskId =
            taskDetailsModal.dataset.taskId;


        if (!taskId) {
            return;
        }


        localStorage.setItem(
            "edit_task_id",
            taskId
        );


        window.location.href =
            "/";

    }
);


deleteTaskButton.addEventListener(
    "click",
    async () => {

        const taskId =
            taskDetailsModal.dataset.taskId;


        if (!taskId) {
            return;
        }


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


            closeTaskDetailsModal();


            /*
             * Reload tasks and calendar
             */

            await loadTasks();


        } catch (error) {

            console.error(
                "Failed to delete task:",
                error
            );


            alert(
                error.message ||
                "Failed to delete task."
            );

        }

    }
);

// ============================================================
// Month navigation
// ============================================================

previousMonth.addEventListener(
    "click",
    () => {

        currentDate.setMonth(
            currentDate.getMonth() - 1
        );

        renderCalendar();

    }
);


nextMonth.addEventListener(
    "click",
    () => {

        currentDate.setMonth(
            currentDate.getMonth() + 1
        );

        renderCalendar();

    }
);


// ============================================================
// Today
// ============================================================

todayButton.addEventListener(
    "click",
    () => {

        currentDate =
            new Date();

        renderCalendar();

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

        window.location.href =
            "/static/login.html";

    }
);


// ============================================================
// Helpers
// ============================================================

function isToday(date) {

    const today =
        new Date();


    return (
        date.getFullYear() ===
            today.getFullYear()

        &&

        date.getMonth() ===
            today.getMonth()

        &&

        date.getDate() ===
            today.getDate()
    );

}

function formatStatus(status) {

    switch (status) {

        case "pending":
            return "Pending";

        case "in_progress":
            return "In Progress";

        case "completed":
            return "Completed";

        default:
            return status || "Unknown";

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
            return priority || "Unknown";

    }

}

function formatDateTime(dateString) {

    const date =
        new Date(dateString);


    if (
        Number.isNaN(
            date.getTime()
        )
    ) {

        return "Invalid date";

    }


    return date.toLocaleString(
        undefined,
        {
            dateStyle: "medium",
            timeStyle: "short"
        }
    );

}

function formatTime(dateString) {

    const date =
        new Date(
            dateString
        );


    return date.toLocaleTimeString(
        "en-US",
        {
            hour: "2-digit",
            minute: "2-digit"
        }
    );

}


function getMonthTaskCount(
    year,
    month
) {

    return tasks.filter(
        task => {

            if (!task.due_date) {
                return false;
            }


            const date =
                new Date(
                    task.due_date
                );


            return (
                date.getFullYear() === year
                &&
                date.getMonth() === month
            );

        }
    ).length;

}


// ============================================================
// Initial load
// ============================================================

loadCurrentUser();

loadTasks();