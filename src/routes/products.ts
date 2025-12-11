import { Router } from "express";
import type { Request } from "express";
import type { User } from "@supabase/supabase-js";
import multer from "multer";
import { supabaseAdmin } from "../supabase.js";
import { requireAuth } from "../middleware/requireAuth.js";
import {
  badRequest,
  serverError,
  successResponse,
  notFound,
} from "../utils/responses.js";

interface AuthRequest extends Request {
  user?: User;
}

const router = Router();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept images only
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Only image files are allowed"));
    }
    cb(null, true);
  },
});

// Get all products with filters
router.get("/", requireAuth, async (req, res) => {
  try {
    const {
      search,
      category,
      // status = 'active',
      limit = 50,
      offset = 0,
    } = req.query;

    let query = supabaseAdmin.from("products").select("*", { count: "exact" });

    // if (search && typeof search === 'string') {
    //   query = query.or(`name.ilike.%${search}%,partNo.ilike.%${search}%,barcode.ilike.%${search}%`);
    // }

    if (category && typeof category === "string") {
      query = query.eq("category", category);
    }

    // if (status && typeof status === 'string' && status !== 'all') {
    //   query = query.eq('status', status);
    // }

    const { data, error, count } = await query
      .order("name", { ascending: true })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error("Error fetching products:", error);
      return serverError(res, "Failed to fetch products");
    }

    return successResponse(res, { products: data, total: count });
  } catch (err) {
    console.error("Error in get products:", err);
    return serverError(res, "Internal server error");
  }
});

// Get single product
router.get("/:id", requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from("products")
      .select("*")
      .eq("id", id)
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        return notFound(res, "Product not found");
      }
      console.error("Error fetching product:", error);
      return serverError(res, "Failed to fetch product");
    }

    return successResponse(res, { product: data });
  } catch (err) {
    console.error("Error in get product:", err);
    return serverError(res, "Internal server error");
  }
});

// Create product
router.post("/", requireAuth, async (req: AuthRequest, res) => {
  try {
    const {
      name,
      partNo,
      // barcode,
      category,
      price,
      selling_price,
      // description,
      image_url,
      // status = 'active',
      // Nutrition fields
      ingredients,
      health_rating,
      calories,
      fat,
      carbs,
      protein,
      sodium,
    } = req.body;

    if (!name || name.trim() === "") {
      return badRequest(res, "Product name is required");
    }

    const { data, error } = await supabaseAdmin
      .from("products")
      .insert({
        name,
        partNo,
        // barcode,
        category,
        price: price || 0,
        selling_price: selling_price || 0,
        // description,
        image_url,
        // status,
        // Nutrition fields
        ingredients: ingredients || null,
        health_rating: health_rating || null,
        calories: calories || null,
        fat: fat || null,
        carbs: carbs || null,
        protein: protein || null,
        sodium: sodium || null,
      })
      .select()
      .single();

    if (error) {
      // if (error.code === '23505') { // Unique violation
      //   return badRequest(res, 'partNo or Barcode already exists');
      // }
      console.error("Error creating product:", error);
      return serverError(res, "Failed to create product");
    }

    return successResponse(res, { product: data }, 201);
  } catch (err) {
    console.error("Error in create product:", err);
    return serverError(res, "Internal server error");
  }
});

// Update product
router.put("/:id", requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;

    const { data, error } = await supabaseAdmin
      .from("products")
      .update(updateData)
      .eq("id", id)
      .select()
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        return notFound(res, "Product not found");
      }
      // if (error.code === '23505') {
      //   return badRequest(res, 'partNo or Barcode already exists');
      // }
      console.error("Error updating product:", error);
      return serverError(res, "Failed to update product");
    }

    return successResponse(res, { product: data });
  } catch (err) {
    console.error("Error in update product:", err);
    return serverError(res, "Internal server error");
  }
});

// Delete product (soft delete by setting status to inactive)
router.delete("/:id", requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin
      .from("products")
      .update({
        /* status: 'discontinued' */
      })
      .eq("id", id);

    if (error) {
      console.error("Error deleting product:", error);
      return serverError(res, "Failed to delete product");
    }

    return successResponse(res, { message: "Product deleted successfully" });
  } catch (err) {
    console.error("Error in delete product:", err);
    return serverError(res, "Internal server error");
  }
});

// Get product categories
router.get("/categories/list", requireAuth, async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("products")
      .select("category")
      .not("category", "is", null)
      .order("category");

    if (error) {
      console.error("Error fetching categories:", error);
      return serverError(res, "Failed to fetch categories");
    }

    const categories = [...new Set(data.map((p) => p.category))];
    return successResponse(res, { categories });
  } catch (err) {
    console.error("Error in get categories:", err);
    return serverError(res, "Internal server error");
  }
});

// Upload product image
router.post(
  "/upload-image",
  requireAuth,
  upload.single("image"),
  async (req, res) => {
    try {
      if (!req.file) {
        return badRequest(res, "No image file provided");
      }

      const file = req.file;
      const fileExt = file.originalname.split(".").pop();
      const fileName = `${Date.now()}-${Math.random()
        .toString(36)
        .substring(7)}.${fileExt}`;
      const filePath = `products/${fileName}`;

      // Upload to Supabase Storage
      const { error: uploadError } = await supabaseAdmin.storage
        .from("product-images")
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadError) {
        console.error("Error uploading to storage:", uploadError);
        return serverError(res, "Failed to upload image");
      }

      // Get public URL
      const { data } = supabaseAdmin.storage
        .from("product-images")
        .getPublicUrl(filePath);

      return successResponse(
        res,
        {
          image_url: data.publicUrl,
          file_path: filePath,
        },
        201
      );
    } catch (err) {
      console.error("Error in upload image:", err);
      return serverError(res, "Internal server error");
    }
  }
);

// Delete product image
router.delete("/delete-image", requireAuth, async (req, res) => {
  try {
    const { file_path } = req.body;

    if (!file_path) {
      return badRequest(res, "File path is required");
    }

    const { error } = await supabaseAdmin.storage
      .from("product-images")
      .remove([file_path]);

    if (error) {
      console.error("Error deleting image:", error);
      return serverError(res, "Failed to delete image");
    }

    return successResponse(res, { message: "Image deleted successfully" });
  } catch (err) {
    console.error("Error in delete image:", err);
    return serverError(res, "Internal server error");
  }
});

export default router;
