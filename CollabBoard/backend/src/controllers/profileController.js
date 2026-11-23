const bcrypt = require('bcrypt');
const db = require('../config/db');
const { getUserById } = require('../models/userModel');

async function getProfileHandler(req, res) {
  try {
    const user = await getUserById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url || null,
      created_at: user.created_at,
      updated_at: user.updated_at,
    });
  } catch (err) {
    console.error('Get profile error:', err);
    res.status(500).json({ message: 'Server error' });
  }
}

async function updateProfileHandler(req, res) {
  try {
    const { name, avatar_url } = req.body;
    if (!name) return res.status(400).json({ message: 'Name is required' });
    await db.execute(
      'UPDATE users SET name = ?, avatar_url = ?, updated_at = NOW() WHERE id = ?',
      [name, avatar_url || null, req.user.id]
    );
    const updated = await getUserById(req.user.id);
    res.json({
      id: updated.id,
      name: updated.name,
      email: updated.email,
      avatar_url: updated.avatar_url || null,
    });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ message: 'Server error' });
  }
}

async function changePasswordHandler(req, res) {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Current password and new password are required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ message: 'New password must be at least 8 characters' });
    }

    const [rows] = await db.execute('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
    if (!rows[0]) return res.status(404).json({ message: 'User not found' });

    const match = await bcrypt.compare(currentPassword, rows[0].password_hash);
    if (!match) {
      return res.status(400).json({ message: 'Incorrect current password' });
    }

    const newHash = await bcrypt.hash(newPassword, 10);
    await db.execute('UPDATE users SET password_hash = ?, updated_at = NOW() WHERE id = ?', [newHash, req.user.id]);
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error('Change password error:', err);
    res.status(500).json({ message: 'Server error' });
  }
}

module.exports = {
  getProfileHandler,
  updateProfileHandler,
  changePasswordHandler,
};
