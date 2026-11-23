
// Temporary test script for Board Sharing API
// Run with: node .\tests\boardSharingTest.js
// Assumes backend server is already running on http://127.0.0.1:5000

async function main() {
  const base = 'http://127.0.0.1:5000/api';
  const rnd = Date.now();

  const owner = {
    name: 'Owner' + rnd,
    email: `owner${rnd}@example.com`,
    password: 'Pass1234'
  };

  const member = {
    name: 'Member' + rnd,
    email: `member${rnd}@example.com`,
    password: 'Pass1234'
  };

  const outsider = {
    name: 'Outsider' + rnd,
    email: `outsider${rnd}@example.com`,
    password: 'Pass1234'
  };

  async function register(u) {
    const res = await fetch(`${base}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: u.name,
        email: u.email,
        password: u.password,
        confirmPassword: u.password
      })
    });

    const txt = await res.text();
    console.log(`REGISTER ${u.email}: ${res.status}\n`, txt);

    if (!res.ok) {
      throw new Error(`Registration failed for ${u.email}`);
    }

    return true;
  }

  async function login(u) {
    const res = await fetch(`${base}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: u.email,
        password: u.password
      })
    });

    const data = await res.json();

    console.log(`LOGIN ${u.email}: ${res.status}`);

    if (!res.ok || !data.token) {
      throw new Error(`Login failed for ${u.email}`);
    }

    return data.token;
  }

  // 1. Register three users
  await register(owner);
  await register(member);
  await register(outsider);

  // 2. Login all users
  const tokenOwner = await login(owner);
  const tokenMember = await login(member);
  const tokenOutsider = await login(outsider);

  // 3. Owner creates a board
  let res = await fetch(`${base}/boards`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenOwner}`
    },
    body: JSON.stringify({
      title: 'TestBoard' + rnd,
      description: 'desc'
    })
  });

  const board = await res.json();

  console.log('CREATE BOARD:', res.status, board);

  if (!res.ok || !board.id) {
    throw new Error('Board creation failed');
  }

  const boardId = board.id;

  // 4. Owner invites member as viewer
  res = await fetch(`${base}/boards/${boardId}/members`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenOwner}`
    },
    body: JSON.stringify({
      email: member.email,
      role: 'viewer'
    })
  });

  console.log('INVITE VIEWER:', res.status, await res.json());

  // 5. Get member list and retrieve actual user ID
  const membersList = await fetch(
    `${base}/boards/${boardId}/members`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tokenOwner}`
      }
    }
  ).then(r => r.json());

  const memberRecord = membersList.find(
    m => m.email === member.email
  );

  const memberId = memberRecord?.user_id;

  if (!memberId) {
    throw new Error('Could not find invited member user ID');
  }

  console.log('MEMBER USER ID:', memberId);

  // 6. List members (owner)
  res = await fetch(`${base}/boards/${boardId}/members`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokenOwner}`
    }
  });

  console.log('LIST MEMBERS (owner):', res.status, await res.json());

  // 7. List members (member)
  res = await fetch(`${base}/boards/${boardId}/members`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokenMember}`
    }
  });

  console.log('LIST MEMBERS (member):', res.status, await res.json());

  // 8. Owner updates member role to editor
  res = await fetch(
    `${base}/boards/${boardId}/members/${memberId}`,
    {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenOwner}`
      },
      body: JSON.stringify({
        role: 'editor'
      })
    }
  );

  console.log(
    'UPDATE TO EDITOR (owner):',
    res.status,
    await res.text()
  );

  // 9. Owner updates member role back to viewer
  res = await fetch(
    `${base}/boards/${boardId}/members/${memberId}`,
    {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenOwner}`
      },
      body: JSON.stringify({
        role: 'viewer'
      })
    }
  );

  console.log(
    'UPDATE TO VIEWER (owner):',
    res.status,
    await res.text()
  );

  // 10. Owner removes member
  res = await fetch(
    `${base}/boards/${boardId}/members/${memberId}`,
    {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${tokenOwner}`
      }
    }
  );

  console.log(
    'REMOVE MEMBER (owner):',
    res.status,
    await res.text()
  );

  // 11. Non-owner tries to invite another user
  res = await fetch(`${base}/boards/${boardId}/members`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokenMember}`
    },
    body: JSON.stringify({
      email: outsider.email,
      role: 'viewer'
    })
  });

  console.log(
    'NON-OWNER INVITE attempt:',
    res.status,
    await res.text()
  );

  // 12. Outsider tries to list members
  res = await fetch(`${base}/boards/${boardId}/members`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokenOutsider}`
    }
  });

  console.log(
    'OUTSIDER LIST attempt:',
    res.status,
    await res.text()
  );

  console.log('\nBOARD SHARING TEST COMPLETED');
}

main().catch(err => {
  console.error('Script error:', err.message);
});
