import html


def render_otp_email_html(otp: str, email: str, year: int = 2025, company_name: str = "KirayaEase Technologies") -> str:
    return f"""
    <html>
      <body style="margin: 0; font-family: Arial, sans-serif;">
        <div style="padding: 50px 40px; position: relative; background: #ffffff;">
          <div style="text-align: center; margin-bottom: 40px;">
            <h2 style="font-size: 28px; font-weight: 600; color: #1e293b; margin: 0 0 12px 0; letter-spacing: -0.5px;">
              Secure Access Code
            </h2>
            <p style="font-size: 16px; color: #64748b; margin: 0;">
              Authentication code sent to <span style="color: #2563eb; font-weight: 500;">{email}</span>
            </p>
          </div>

          <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border: 2px solid #e2e8f0; border-radius: 20px; padding: 40px; text-align: center; margin: 40px 0; position: relative; overflow: hidden;">
            <div style="position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 200px; height: 2px; background: linear-gradient(90deg, transparent, #2563eb, transparent); opacity: 0.4;"></div>
            <p style="font-size: 12px; color: #64748b; margin: 0 0 20px 0; text-transform: uppercase; letter-spacing: 2px; font-weight: 600;">
              VERIFICATION CODE
            </p>
            <div style="font-size: 42px; font-weight: 700; color: #2563eb; letter-spacing: 12px; font-family: 'JetBrains Mono', 'Fira Code', monospace; margin: 0;">
              {otp}
            </div>
          </div>

          <div style="text-align: center; margin: 40px 0;">
            <a href="#" style="background: linear-gradient(135deg, #2563eb, #1d4ed8); color: #ffffff; padding: 16px 40px; text-decoration: none; border-radius: 12px; font-size: 16px; font-weight: 600; display: inline-block; box-shadow: 0 8px 32px rgba(37, 99, 235, 0.25); border: 1px solid rgba(255,255,255,0.1); transition: all 0.3s ease;">
              Authenticate Now
            </a>
          </div>

          <div style="border-top: 1px solid #e2e8f0; padding-top: 32px; text-align: center;">
            <h3 style="font-size: 18px; font-weight: 600; color: #1e293b; margin: 0 0 16px 0;">
              Need Assistance?
            </h3>
            <p style="font-size: 14px; color: #64748b; margin: 0 0 24px 0; line-height: 1.6;">
              Our security team is available 24/7 to help with authentication issues
            </p>
            <div style="display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
              <a href="mailto:security@kirayaease.com" style="color: #2563eb; text-decoration: none; font-size: 14px; font-weight: 500; display: flex; align-items: center; gap: 8px;">
                <span style="width: 20px; height: 20px; background: linear-gradient(135deg, #2563eb, #1d4ed8); border-radius: 4px; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; color: #ffffff;">📧</span>
                mail@kirayaeasellp.com
              </a>
            </div>
          </div>
        </div>

        <!-- Email Footer -->
        <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border-top: 1px solid #e2e8f0; text-align: center; padding: 32px 40px; color: #64748b; font-size: 12px;">
          <p style="margin: 0 0 12px 0;">
            © {year} {company_name}. All rights reserved.
          </p>
          <p style="margin: 0 0 20px 0;">
            This secure message was sent to {email}
          </p>
          <div style="display: flex; justify-content: center; gap: 16px; flex-wrap: wrap;">
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Privacy Policy</a>
            <span>•</span>
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Security Center</a>
            <span>•</span>
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Unsubscribe</a>
          </div>
        </div>
      </body>
    </html>
    """


def render_rent_due_email_html(
    tenant_name: str,
    apt_name: str,
    due_date: str,
    amount: str,
    email: str,
    year: int = 2025,
    company_name: str = "KirayaEase Technologies",
) -> str:
    """Friendly rent-due reminder; same layout as the OTP template. All text fields are HTML-escaped."""
    t = html.escape(tenant_name, quote=False)
    apt = html.escape(apt_name, quote=False)
    d = html.escape(due_date, quote=False)
    amt = html.escape(amount, quote=False)
    em = html.escape(email, quote=False)
    yr = html.escape(str(year), quote=False)
    co = html.escape(company_name, quote=False)
    return f"""
    <html>
      <body style="margin: 0; font-family: Arial, sans-serif;">
        <div style="padding: 50px 40px; position: relative; background: #ffffff;">
          <div style="text-align: center; margin-bottom: 40px;">
            <h2 style="font-size: 28px; font-weight: 600; color: #1e293b; margin: 0 0 12px 0; letter-spacing: -0.5px;">
              Rent due reminder
            </h2>
            <p style="font-size: 16px; color: #64748b; margin: 0;">
              It's rent day <span style="color: #2563eb; font-weight: 500;">{t}</span>! Please complete your rent due amount for the month of <span style="color: #1e293b; font-weight: 600;">{d}</span> for <span style="color: #1e293b; font-weight: 500;">{apt}</span>.
            </p>
          </div>

          <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border: 2px solid #e2e8f0; border-radius: 20px; padding: 40px; text-align: center; margin: 40px 0; position: relative; overflow: hidden;">
            <div style="position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 200px; height: 2px; background: linear-gradient(90deg, transparent, #2563eb, transparent); opacity: 0.4;"></div>
            <p style="font-size: 12px; color: #64748b; margin: 0 0 20px 0; text-transform: uppercase; letter-spacing: 2px; font-weight: 600;">
              AMOUNT DUE
            </p>
            <div style="font-size: 42px; font-weight: 700; color: #2563eb; letter-spacing: 1px; font-family: 'JetBrains Mono', 'Fira Code', monospace; margin: 0 0 16px 0;">
              {amt}
            </div>
            <p style="font-size: 15px; color: #64748b; margin: 0; line-height: 1.6;">
              Due on <span style="color: #1e293b; font-weight: 600;">{d}</span>
            </p>
          </div>

          <div style="border-top: 1px solid #e2e8f0; padding-top: 32px; text-align: center;">
            <h3 style="font-size: 18px; font-weight: 600; color: #1e293b; margin: 0 0 16px 0;">
              Need assistance?
            </h3>
            <p style="font-size: 14px; color: #64748b; margin: 0 0 24px 0; line-height: 1.6;">
              Questions about your rent or this notice? We're here to help.
            </p>
            <div style="display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
              <a href="mailto:security@kirayaease.com" style="color: #2563eb; text-decoration: none; font-size: 14px; font-weight: 500; display: flex; align-items: center; gap: 8px;">
                <span style="width: 20px; height: 20px; background: linear-gradient(135deg, #2563eb, #1d4ed8); border-radius: 4px; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; color: #ffffff;">📧</span>
                mail@kirayaeasellp.com
              </a>
            </div>
          </div>
        </div>

        <!-- Email Footer -->
        <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border-top: 1px solid #e2e8f0; text-align: center; padding: 32px 40px; color: #64748b; font-size: 12px;">
          <p style="margin: 0 0 12px 0;">
            © {yr} {co}. All rights reserved.
          </p>
          <p style="margin: 0 0 20px 0;">
            This message was sent to {em}
          </p>
          <div style="display: flex; justify-content: center; gap: 16px; flex-wrap: wrap;">
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Privacy Policy</a>
            <span>•</span>
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Security Center</a>
            <span>•</span>
            <a href="#" style="color: #64748b; text-decoration: none; font-size: 11px;"> Unsubscribe</a>
          </div>
        </div>
      </body>
    </html>
    """


def render_tenant_welcome_email_html(
    tenant_name: str,
    apt_name: str,
    email: str,
    year: int = 2025,
    company_name: str = "KirayaEase Technologies",
) -> str:
    """Warm tenant welcome email; same visual layout style as existing templates."""
    t = html.escape(tenant_name, quote=False)
    apt = html.escape(apt_name, quote=False)
    em = html.escape(email, quote=False)
    yr = html.escape(str(year), quote=False)
    co = html.escape(company_name, quote=False)
    return f"""
    <html>
      <body style="margin: 0; font-family: Arial, sans-serif;">
        <div style="padding: 50px 40px; position: relative; background: #ffffff;">
          <div style="text-align: center; margin-bottom: 40px;">
            <h2 style="font-size: 28px; font-weight: 600; color: #1e293b; margin: 0 0 12px 0; letter-spacing: -0.5px;">
              Welcome home, {t}!
            </h2>
            <p style="font-size: 16px; color: #64748b; margin: 0;">
              Welcome to <span style="color: #1e293b; font-weight: 600;">{apt}</span>. We're excited to have you onboard.
            </p>
          </div>

          <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border: 2px solid #e2e8f0; border-radius: 20px; padding: 40px; text-align: center; margin: 40px 0; position: relative; overflow: hidden;">
            <div style="position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 200px; height: 2px; background: linear-gradient(90deg, transparent, #2563eb, transparent); opacity: 0.4;"></div>
            <p style="font-size: 12px; color: #64748b; margin: 0 0 20px 0; text-transform: uppercase; letter-spacing: 2px; font-weight: 600;">
              NEXT STEP
            </p>
            <p style="font-size: 18px; color: #1e293b; margin: 0; line-height: 1.7; font-weight: 500;">
              You will shortly receive a DocuSeal link to review and sign your lease document.
            </p>
          </div>

          <div style="border-top: 1px solid #e2e8f0; padding-top: 32px; text-align: center;">
            <h3 style="font-size: 18px; font-weight: 600; color: #1e293b; margin: 0 0 16px 0;">
              Need assistance?
            </h3>
            <p style="font-size: 14px; color: #64748b; margin: 0 0 24px 0; line-height: 1.6;">
              If you have any questions, our team is happy to help.
            </p>
            <div style="display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
              <a href="mailto:security@kirayaease.com" style="color: #2563eb; text-decoration: none; font-size: 14px; font-weight: 500; display: flex; align-items: center; gap: 8px;">
                <span style="width: 20px; height: 20px; background: linear-gradient(135deg, #2563eb, #1d4ed8); border-radius: 4px; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; color: #ffffff;">📧</span>
                mail@kirayaeasellp.com
              </a>
            </div>
          </div>
        </div>

        <div style="background: linear-gradient(135deg, #f8fafc, #f1f5f9); border-top: 1px solid #e2e8f0; text-align: center; padding: 32px 40px; color: #64748b; font-size: 12px;">
          <p style="margin: 0 0 12px 0;">
            © {yr} {co}. All rights reserved.
          </p>
          <p style="margin: 0;">
            This message was sent to {em}
          </p>
        </div>
      </body>
    </html>
    """
