/**
 * Wishlist Controller — thin HTTP adapter over wishlist.service
 */

const { sendSuccess } = require('../utils/response');
const wishlistService = require('../services/wishlist.service');

// GET /api/wishlist
async function listWishlist(req, res, next) {
  try {
    const items = await wishlistService.listWishlist(req.user.id);
    sendSuccess(res, items);
  } catch (err) {
    next(err);
  }
}

// POST /api/wishlist
async function createWishlistItem(req, res, next) {
  try {
    const item = await wishlistService.createWishlistItem(req.user.id, req.body);
    sendSuccess(res, item, 201);
  } catch (err) {
    next(err);
  }
}

// PUT /api/wishlist/:id
async function updateWishlistItem(req, res, next) {
  try {
    const item = await wishlistService.updateWishlistItem(req.user.id, req.params.id, req.body);
    sendSuccess(res, item);
  } catch (err) {
    next(err);
  }
}

// PATCH /api/wishlist/:id/deduct
async function toggleDeduct(req, res, next) {
  try {
    const item = await wishlistService.toggleDeduct(req.user.id, req.params.id);
    sendSuccess(res, item);
  } catch (err) {
    next(err);
  }
}

// PATCH /api/wishlist/:id/purchase
async function markPurchased(req, res, next) {
  try {
    const item = await wishlistService.markPurchased(req.user.id, req.params.id);
    sendSuccess(res, item);
  } catch (err) {
    next(err);
  }
}

// DELETE /api/wishlist/:id
async function deleteWishlistItem(req, res, next) {
  try {
    const result = await wishlistService.deleteWishlistItem(req.user.id, req.params.id);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  listWishlist,
  createWishlistItem,
  updateWishlistItem,
  toggleDeduct,
  markPurchased,
  deleteWishlistItem,
};
