const request = require('supertest');
const mongoose = require('mongoose');

// Use in-memory mock for tests
jest.mock('mongoose', () => {
  const actual = jest.requireActual('mongoose');
  return {
    ...actual,
    connect: jest.fn().mockResolvedValue(true),
    connection: { readyState: 1 }
  };
});

jest.mock('../src/models/Task', () => {
  return {
    find: jest.fn().mockResolvedValue([
      { _id: '1', title: 'Test task', done: false, createdAt: new Date() }
    ]),
    findById: jest.fn().mockResolvedValue({ _id: '1', title: 'Test task', done: false }),
    findByIdAndDelete: jest.fn().mockResolvedValue({ _id: '1', title: 'Test task' }),
    findByIdAndUpdate: jest.fn().mockResolvedValue({ _id: '1', title: 'Test task', done: true }),
    prototype: {
      save: jest.fn().mockResolvedValue({ _id: '1', title: 'Test task', done: false })
    }
  };
});

describe('Health endpoint', () => {
  it('GET /health should return status ok', async () => {
    const express = require('express');
    const app = express();
    app.use('/health', require('../src/routes/health'));
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Tasks API', () => {
  it('should return tasks array on GET /api/tasks', async () => {
    const express = require('express');
    const app = express();
    app.use(express.json());
    app.use('/api/tasks', require('../src/routes/tasks'));
    const res = await request(app).get('/api/tasks');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
