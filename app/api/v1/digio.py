# # # @app.post('/digio-kyc')
# # # async def initiate_digio(request: DigioKYC):
# # #     full_name = request.first_name + " " + request.last_name
# # #     body = {
# # #         "customer_identifier": request.phone_number,
# # #         "customer_name": full_name,
# # #         "template_name": "KE_DIGILOCKER_INTEGRATION",
# # #         "notify_customer": "false",
# # #         "generate_access_token": "true",
# # #         "request_details": {}
# # #     }
# # #     digio = DigioClient()
# # #     response = digio.initiate_kyc(body)
# # #     return response

# # # @app.post("/webhooks/digio")
# # # async def digio_webhook(request: Request):
# # #     try:
# # #         raw = await request.body()
# # #         payload = json.loads(raw.decode("utf-8"))
# # #     except Exception:
# # #         # ack quickly; log parse error
# # #         print("⚠️ Digio webhook: JSON parse error")
# # #         return {"ok": True}

# # #     print(payload)

# # #     digilocker_data = payload["payload"]["digilocker_request"]
# # #     kyc_request_id = digilocker_data["kyc_request_id"]
# # #     state = digilocker_data['state']

# # #     documents = DigioClient().fetch_user_data(kyc_request_id)
# # #     aadhaar_pan_data = DigioClient().extract_aadhaar_pan(documents)
# # #     pan_number = aadhaar_pan_data["aadhaar"]['id_number']
# # #     aadhar_number = aadhaar_pan_data["pan"]['id_number']
# # #     full_name = aadhaar_pan_data["aadhaar"]['name']
# # #     first_name, last_name = full_name.split(" ", 1)
# # #     dob = aadhaar_pan_data["pan"]['dob']

# # #     onboard_user = handle_user_onboarding(
# # #             session_token = request.session_token,
# # #             first_name = first_name,
# # #             last_name = last_name, 
# # #             dob = dob,
# # #             aadhaar =  aadhar_number,
# # #             pan = pan_number
# # #         )
# # #     return onboard_user

# # #     # if state == 'COMPLETED':
# # #     #     pass
# # #     # return {"success": "True"}