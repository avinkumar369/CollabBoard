
const BASE_URL = 'http://localhost:5000/api';

const uniqueEmail = `collabtest${Date.now()}@example.com`;
const password = 'TestPass123!';

async function runTests() {
  console.log('\n===== COLLABBOARD AUTH TESTS =====\n');

  // 1. Registration
  const registerResponse = await fetch(`${BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Collab Test',
      email: uniqueEmail,
      password,
      confirmPassword: password
    })
  });

  const registerData = await registerResponse.json();
  console.log('REGISTER:', registerResponse.status);

  if (registerResponse.status !== 201) {
    console.log(registerData);
    return;
  }

  // 2. Login
  const loginResponse = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: uniqueEmail,
      password
    })
  });

  const loginData = await loginResponse.json();
  console.log('LOGIN:', loginResponse.status);

  if (!loginData.token) {
    console.log(loginData);
    return;
  }

  // 3. Verify JWT
  const meResponse = await fetch(`${BASE_URL}/auth/me`, {
    headers: {
      Authorization: `Bearer ${loginData.token}`
    }
  });

  const meData = await meResponse.json();
  console.log('JWT / ME:', meResponse.status);
  console.log('USER:', meData);

  // 4. Invalid token
  const invalidResponse = await fetch(`${BASE_URL}/auth/me`, {
    headers: {
      Authorization: 'Bearer invalid-token'
    }
  });

  console.log('INVALID TOKEN:', invalidResponse.status);

  console.log('\n===== TESTS COMPLETED =====');
}

runTests().catch(console.error);
