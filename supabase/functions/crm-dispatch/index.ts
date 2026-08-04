import { createClient } from '@supabase/supabase-js';

type Channel = 'sms' | 'whatsapp';
type NotificationTemplate = {
  template_key: string;
  channel: Channel;
  sms_message_id: string;
  sms_sender_id: string;
  sms_entity_id: string;
  whatsapp_template_name: string;
  whatsapp_template_id: string;
  whatsapp_sender: string;
  enabled: boolean;
};

type Followup = {
  id: string;
  lead_id: string;
  channel: Channel;
  template_key: string;
  retry_count: number;
  leads: {
    customer_id: string | null;
    customer_name: string;
    mobile: string;
    whatsapp_number: string;
    event_type: string;
    event_date: string | null;
    guest_count: number | null;
    event_location: string;
  } | null;
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json' },
});

const renderMessage = (followup: Followup) => {
  const lead = followup.leads;
  const name = lead?.customer_name || 'there';
  const event = lead?.event_type?.replaceAll('_', ' ') || 'event';
  const guests = lead?.guest_count ? ` for ${lead.guest_count} guests` : '';
  if (followup.template_key.includes('checkout')) {
    return `Hi ${name}, your BookMyPlatter catering checkout${guests} is waiting. Complete your booking or reply for help.`;
  }
  if (followup.template_key.includes('menu')) {
    return `Hi ${name}, here are live BookMyPlatter menu options for your ${event}. Reply with your date, guests and budget for assistance.`;
  }
  if (followup.template_key.includes('reviews')) {
    return `Hi ${name}, BookMyPlatter has verified caterers, reviews and popular packages for your ${event}. Reply to shortlist menus.`;
  }
  if (followup.template_key.includes('final')) {
    return `Hi ${name}, this is your final BookMyPlatter follow-up for the current offer. Reply to book or request a callback.`;
  }
  return `Thanks ${name} for contacting BookMyPlatter. Our catering specialist will help with your ${event}${guests}.`;
};

const sendSms = async (phone: string, message: string, template: NotificationTemplate) => {
  const key = Deno.env.get('FAST2SMS_API_KEY');
  const sender = template.sms_sender_id || Deno.env.get('FAST2SMS_SENDER_ID');
  const templateId = template.sms_message_id;
  if (!key || !sender || !templateId) throw new Error('Fast2SMS SMS environment or template is incomplete');
  const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
    method: 'POST',
    headers: { authorization: key, 'content-type': 'application/json' },
    body: JSON.stringify({ route: 'dlt', sender_id: sender, message, template_id: templateId, entity_id: template.sms_entity_id, language: 'english', numbers: phone }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`Fast2SMS rejected request (${response.status})`);
  return { templateId, payload };
};

const sendWhatsApp = async (phone: string, message: string, template: NotificationTemplate) => {
  const apiUrl = Deno.env.get('FAST2SMS_WHATSAPP_API_URL') ?? Deno.env.get('WHATSAPP_API_URL');
  const key = Deno.env.get('FAST2SMS_WHATSAPP_API_KEY') ?? Deno.env.get('WHATSAPP_ACCESS_TOKEN');
  const templateName = template.whatsapp_template_name;
  const templateId = template.whatsapp_template_id;
  if (!apiUrl || !key || !templateName || !templateId) throw new Error('WhatsApp environment or template is incomplete');
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: { authorization: key, 'content-type': 'application/json' },
    body: JSON.stringify({ to: phone, sender: template.whatsapp_sender, template_name: templateName, template_id: templateId, message }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`WhatsApp rejected request (${response.status})`);
  return { templateId, payload };
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const secret = Deno.env.get('CRM_DISPATCH_SECRET');
  if (secret && req.headers.get('x-crm-dispatch-secret') !== secret) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  const { data, error } = await supabase
    .from('followups')
    .select('id,lead_id,channel,template_key,retry_count,leads(customer_id,customer_name,mobile,whatsapp_number,event_type,event_date,guest_count,event_location)')
    .eq('status', 'queued')
    .lte('due_at', new Date().toISOString())
    .order('due_at')
    .limit(25);

  if (error) return json({ error: error.message }, 500);
  const results = [];
  for (const followup of (data ?? []) as Followup[]) {
    const lead = followup.leads;
    const recipient = followup.channel === 'sms' ? lead?.mobile : lead?.whatsapp_number || lead?.mobile;
    const message = renderMessage(followup);
    const { data: template, error: templateError } = await supabase
      .from('notification_templates')
      .select('template_key,channel,sms_message_id,sms_sender_id,sms_entity_id,whatsapp_template_name,whatsapp_template_id,whatsapp_sender,enabled')
      .eq('template_key', followup.template_key)
      .eq('channel', followup.channel)
      .eq('enabled', true)
      .maybeSingle();
    if (templateError) {
      await supabase.from('followups').update({ last_error: templateError.message }).eq('id', followup.id);
      results.push({ id: followup.id, status: 'failed', error: templateError.message });
      continue;
    }
    if (!template) {
      const error = `No enabled ${followup.channel} template for ${followup.template_key}`;
      await supabase.from('followups').update({ status: 'failed', last_error: error }).eq('id', followup.id);
      results.push({ id: followup.id, status: 'failed', error });
      continue;
    }
    const notificationTemplate = template as NotificationTemplate;
    const log = {
      lead_id: followup.lead_id,
      customer_id: lead?.customer_id,
      channel: followup.channel,
      template_key: followup.template_key,
      recipient: recipient ?? '',
      message,
    };
    try {
      if (!recipient) throw new Error('Lead has no recipient phone number');
      const provider = followup.channel === 'sms'
        ? await sendSms(recipient, message, notificationTemplate)
        : await sendWhatsApp(recipient, message, notificationTemplate);
      const { data: communication } = await supabase.from('communication_logs').insert({ ...log, template_id: provider.templateId, status: 'sent', sent_at: new Date().toISOString(), metadata: provider.payload }).select('id').single();
      if (communication?.id && followup.channel === 'sms') await supabase.from('sms_logs').insert({ id: communication.id, dlt_template_id: provider.templateId, fast2sms_response: provider.payload });
      if (communication?.id && followup.channel === 'whatsapp') await supabase.from('whatsapp_logs').insert({ id: communication.id, whatsapp_template_id: provider.templateId, provider_response: provider.payload });
      await supabase.from('followups').update({ status: 'sent', completed_at: new Date().toISOString() }).eq('id', followup.id);
      await supabase.from('leads').update({ last_follow_up_at: new Date().toISOString() }).eq('id', followup.lead_id);
      results.push({ id: followup.id, status: 'sent' });
    } catch (err) {
      await supabase.from('communication_logs').insert({ ...log, status: 'failed', error: err instanceof Error ? err.message : String(err) });
      await supabase.from('followups').update({ retry_count: followup.retry_count + 1, last_error: err instanceof Error ? err.message : String(err), status: followup.retry_count >= 2 ? 'failed' : 'queued' }).eq('id', followup.id);
      results.push({ id: followup.id, status: 'failed' });
    }
  }

  return json({ processed: results.length, results });
});
