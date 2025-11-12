import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse } from '../utils/responses.js';
import { requirePerm } from '../middleware/requirePerm.js';
import { PERM } from '../perms.js';

const router = Router();

router.post('/create-supplier',requireAuth,async(req,res)=>{
    try{
        const{companyname, email, companyregistration, phonenumber, faxnumber, bankacc, bankaccno, country, state, address, postzipcode, city} = req.body
        if(!companyname){
            return badRequest(res, 'Company name should not be blank')
        }

        if(!email || typeof email !== 'string'){
            return badRequest(res, 'Valid email is required')
        }
        
        if(!phonenumber || typeof phonenumber!== 'number'){
            return badRequest(res, 'Phone number required')
        }

        if(!bankacc || typeof bankacc !== 'number'){
            return badRequest(res, 'bank accoount should not be empty ')
        }
        if(bankacc !== bankaccno){
            return badRequest(res, 'bank account doesnt match')
        }
    } catch(err) {
        console.error("Error creating the supplier")
    }
})

export default router;
