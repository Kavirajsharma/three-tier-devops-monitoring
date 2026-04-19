import { useState, useEffect } from "react";
import axios from "axios";
import "./App.css";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:5000";

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${API_URL}/api/tasks`);
      setTasks(res.data);
      setError(null);
    } catch (err) {
      setError("Could not connect to backend. Is it running?");
    } finally {
      setLoading(false);
    }
  };

  const addTask = async () => {
    if (!newTask.trim()) return;
    try {
      const res = await axios.post(`${API_URL}/api/tasks`, { title: newTask });
      setTasks([...tasks, res.data]);
      setNewTask("");
    } catch (err) {
      setError("Failed to add task.");
    }
  };

  const deleteTask = async (id) => {
    try {
      await axios.delete(`${API_URL}/api/tasks/${id}`);
      setTasks(tasks.filter((t) => t._id !== id));
    } catch (err) {
      setError("Failed to delete task.");
    }
  };

  const toggleTask = async (id, done) => {
    try {
      const res = await axios.put(`${API_URL}/api/tasks/${id}`, { done: !done });
      setTasks(tasks.map((t) => (t._id === id ? res.data : t)));
    } catch (err) {
      setError("Failed to update task.");
    }
  };

  return (
    <div className="app">
      <header className="header">
        <div className="logo">
          <span className="logo-icon">⬡</span>
          <h1>DevTask</h1>
        </div>
        <p className="subtitle">Local DevSecOps Demo App</p>
      </header>

      <main className="main">
        <div className="card">
          <h2 className="section-title">Add Task</h2>
          <div className="input-row">
            <input
              className="input"
              type="text"
              placeholder="What needs to be done?"
              value={newTask}
              onChange={(e) => setNewTask(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addTask()}
            />
            <button className="btn-add" onClick={addTask}>
              Add
            </button>
          </div>
          {error && <p className="error">{error}</p>}
        </div>

        <div className="card">
          <h2 className="section-title">
            Tasks{" "}
            <span className="count">{tasks.filter((t) => !t.done).length} remaining</span>
          </h2>

          {loading ? (
            <div className="loader">Loading...</div>
          ) : tasks.length === 0 ? (
            <p className="empty">No tasks yet. Add one above!</p>
          ) : (
            <ul className="task-list">
              {tasks.map((task) => (
                <li key={task._id} className={`task-item ${task.done ? "done" : ""}`}>
                  <button
                    className="check-btn"
                    onClick={() => toggleTask(task._id, task.done)}
                    aria-label="Toggle task"
                  >
                    {task.done ? "✓" : ""}
                  </button>
                  <span className="task-title">{task.title}</span>
                  <button
                    className="delete-btn"
                    onClick={() => deleteTask(task._id)}
                    aria-label="Delete task"
                  >
                    ×
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="info-bar">
          <span>🟢 Frontend running</span>
          <span>API: {API_URL}</span>
          <button onClick={fetchTasks} className="refresh-btn">Refresh</button>
        </div>
      </main>
    </div>
  );
}

export default App;
