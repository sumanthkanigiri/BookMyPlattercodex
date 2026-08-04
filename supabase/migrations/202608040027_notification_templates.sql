create table if not exists public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  template_key text not null,
  feature text not null,
  channel public.crm_channel not null,
  sms_message_id text not null default '',
  sms_sender_id text not null default 'BMPLTR',
  sms_entity_name text not null default 'AADHYA CATERERS',
  sms_entity_id text not null default '1701178289373379990',
  whatsapp_template_name text not null default '',
  whatsapp_template_id text not null default '',
  whatsapp_sender text not null default '+919995559338',
  variables jsonb not null default '["customer_name","order_or_event","event_date","event_time_or_venue","guest_count_or_contact","support_number","tracking_url_or_rider_mobile"]'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(template_key, channel)
);

create index if not exists notification_templates_channel_idx on public.notification_templates(channel, enabled);
create index if not exists notification_templates_feature_idx on public.notification_templates(feature);

drop trigger if exists set_notification_templates_updated_at on public.notification_templates;
create trigger set_notification_templates_updated_at before update on public.notification_templates for each row execute function public.set_crm_updated_at();

alter table public.notification_templates enable row level security;

drop policy if exists "staff read notification templates" on public.notification_templates;
create policy "staff read notification templates" on public.notification_templates for select using (public.is_admin_staff());
drop policy if exists "staff manage notification templates" on public.notification_templates;
create policy "staff manage notification templates" on public.notification_templates for all using (public.is_admin_staff()) with check (public.is_admin_staff());

do $$ begin alter publication supabase_realtime add table public.notification_templates; exception when duplicate_object then null; end $$;

insert into public.notification_templates(template_key, feature, channel, sms_message_id, whatsapp_template_name, whatsapp_template_id)
values
  ('verification_otp', 'OTP Verification', 'sms', '219697', '', ''),
  ('verification_otp', 'OTP Verification', 'whatsapp', '', 'verification_otp', '1968782073799934'),
  ('order_confirmation', 'Booking Confirmed', 'sms', '219698', '', ''),
  ('order_confirmation', 'Booking Confirmed', 'whatsapp', '', 'order_confirmation', '4460867297564638'),
  ('order_cancelled', 'Order Cancelled', 'sms', '219699', '', ''),
  ('order_cancelled', 'Order Cancelled', 'whatsapp', '', 'order_cancelled', '3243786432471828'),
  ('booking_reminder_before', 'Booking Reminder', 'sms', '219700', '', ''),
  ('booking_reminder_before', 'Booking Reminder', 'whatsapp', '', 'booking_reminder_before', '1585849556227167'),
  ('followup1', 'Marketing / Event Offer', 'sms', '219701', '', ''),
  ('followup1', 'Marketing / Event Offer', 'whatsapp', '', 'followup1', '979324475166912'),
  ('order_status_update', 'Order Status Update', 'sms', '219702', '', ''),
  ('order_status_update', 'Order Status Update', 'whatsapp', '', 'order_status_update', '1712842953093056'),
  ('catering_enquiry_followup', 'Catering Enquiry Follow-up', 'sms', '219703', '', ''),
  ('catering_enquiry_followup', 'Catering Enquiry Follow-up', 'whatsapp', '', 'catering_enquiry_followup', '2299529843910253'),
  ('order_completed', 'Order Completed', 'sms', '219704', '', ''),
  ('order_completed', 'Order Completed', 'whatsapp', '', 'order_completed', '1798069618020567'),
  ('complete_your_booking', 'Order Received', 'sms', '219705', '', ''),
  ('complete_your_booking', 'Order Received', 'whatsapp', '', 'complete_your_booking', '3368694109946598'),
  ('new_catering_order', 'New Catering Order (Admin)', 'sms', '219706', '', ''),
  ('new_catering_order', 'New Catering Order (Admin)', 'whatsapp', '', 'new_catering_order', '1047426024362163'),
  ('new_enquiry_admin', 'New Enquiry (Admin)', 'sms', '219707', '', ''),
  ('order_out_for_delivery', 'Order Out For Delivery', 'sms', '219789', '', ''),
  ('order_out_for_delivery', 'Order Out For Delivery', 'whatsapp', '', 'order_out_for_delivery', '2127134847898347'),
  ('food_tasting_confirmation', 'Food Tasting Confirmed', 'whatsapp', '', 'food_tasting_confirmation', '3168959119961942'),
  ('tasting_confirmed', 'Tasting Confirmed', 'whatsapp', '', 'tasting_confirmed', '1062674203377461'),
  ('payment_completed', 'Payment Completed', 'sms', '25325', '', ''),
  ('payment_completed', 'Payment Completed', 'whatsapp', '', 'payment_completed', '1015322124617099'),
  ('followup2', 'Follow-up 2', 'whatsapp', '', 'followup2', '2165645117335724'),
  ('followup3', 'Follow-up 3', 'whatsapp', '', 'followup3', '1410249867647028'),
  ('followup4', 'Follow-up 4', 'whatsapp', '', 'followup4', '2056884541589851'),
  ('checkout_15_min_sms', 'Checkout Recovery 15 Minutes SMS', 'sms', '219705', '', ''),
  ('checkout_15_min_whatsapp', 'Checkout Recovery 15 Minutes WhatsApp', 'whatsapp', '', 'complete_your_booking', '3368694109946598'),
  ('checkout_6_hour_whatsapp', 'Checkout Recovery 6 Hours WhatsApp', 'whatsapp', '', 'complete_your_booking', '3368694109946598'),
  ('checkout_12_hour_sms', 'Checkout Recovery 12 Hours SMS', 'sms', '219705', '', ''),
  ('checkout_24_hour_whatsapp', 'Checkout Recovery 24 Hours WhatsApp', 'whatsapp', '', 'complete_your_booking', '3368694109946598'),
  ('checkout_3_day_final', 'Checkout Recovery Final Reminder', 'whatsapp', '', 'followup4', '2056884541589851'),
  ('enquiry_thank_you_sms', 'Enquiry Immediate SMS', 'sms', '219703', '', ''),
  ('enquiry_thank_you_whatsapp', 'Enquiry Immediate WhatsApp', 'whatsapp', '', 'catering_enquiry_followup', '2299529843910253'),
  ('enquiry_30_min_reminder', 'Enquiry 30 Minute Reminder', 'whatsapp', '', 'followup1', '979324475166912'),
  ('enquiry_24_hour_menu', 'Enquiry Menu Follow-up', 'whatsapp', '', 'followup2', '2165645117335724'),
  ('enquiry_3_day_reviews', 'Enquiry Reviews Follow-up', 'whatsapp', '', 'followup3', '1410249867647028'),
  ('enquiry_7_day_final_offer', 'Enquiry Final Offer', 'sms', '219701', '', ''),
  ('whatsapp_click_thank_you_sms', 'WhatsApp Lead SMS', 'sms', '219703', '', ''),
  ('whatsapp_click_thank_you_whatsapp', 'WhatsApp Lead Reply', 'whatsapp', '', 'catering_enquiry_followup', '2299529843910253'),
  ('callback_request_thank_you_sms', 'Callback Thank You SMS', 'sms', '219703', '', ''),
  ('callback_request_thank_you_whatsapp', 'Callback Thank You WhatsApp', 'whatsapp', '', 'catering_enquiry_followup', '2299529843910253'),
  ('food_tasting_thank_you_whatsapp', 'Food Tasting Request WhatsApp', 'whatsapp', '', 'food_tasting_confirmation', '3168959119961942'),
  ('whatsapp_click_30_min_reminder', 'WhatsApp Lead 30 Minute Reminder', 'whatsapp', '', 'followup1', '979324475166912'),
  ('whatsapp_click_24_hour_menu', 'WhatsApp Lead Menu Follow-up', 'whatsapp', '', 'followup2', '2165645117335724'),
  ('whatsapp_click_3_day_reviews', 'WhatsApp Lead Reviews Follow-up', 'whatsapp', '', 'followup3', '1410249867647028'),
  ('whatsapp_click_7_day_final_offer', 'WhatsApp Lead Final Offer', 'sms', '219701', '', ''),
  ('callback_request_30_min_reminder', 'Callback 30 Minute Reminder', 'whatsapp', '', 'followup1', '979324475166912'),
  ('callback_request_24_hour_menu', 'Callback Menu Follow-up', 'whatsapp', '', 'followup2', '2165645117335724'),
  ('callback_request_3_day_reviews', 'Callback Reviews Follow-up', 'whatsapp', '', 'followup3', '1410249867647028'),
  ('callback_request_7_day_final_offer', 'Callback Final Offer', 'sms', '219701', '', ''),
  ('food_tasting_30_min_reminder', 'Food Tasting 30 Minute Reminder', 'whatsapp', '', 'tasting_confirmed', '1062674203377461'),
  ('food_tasting_24_hour_menu', 'Food Tasting Menu Follow-up', 'whatsapp', '', 'followup2', '2165645117335724'),
  ('food_tasting_3_day_reviews', 'Food Tasting Reviews Follow-up', 'whatsapp', '', 'followup3', '1410249867647028'),
  ('food_tasting_7_day_final_offer', 'Food Tasting Final Offer', 'sms', '219701', '', '')
on conflict (template_key, channel) do update set
  feature = excluded.feature,
  sms_message_id = excluded.sms_message_id,
  sms_sender_id = excluded.sms_sender_id,
  sms_entity_name = excluded.sms_entity_name,
  sms_entity_id = excluded.sms_entity_id,
  whatsapp_template_name = excluded.whatsapp_template_name,
  whatsapp_template_id = excluded.whatsapp_template_id,
  whatsapp_sender = excluded.whatsapp_sender,
  variables = excluded.variables,
  enabled = true,
  updated_at = now();
