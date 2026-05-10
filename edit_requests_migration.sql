-- Create the edit_requests table
CREATE TABLE IF NOT EXISTS edit_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL, -- 'farmers', 'farms'
    entity_id UUID NOT NULL,
    field_name TEXT NOT NULL, -- key of the field
    field_label TEXT, -- human readable name
    old_value TEXT,
    new_value TEXT NOT NULL,
    requested_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add explicit updated_at trigger mechanism if supported, or let Flutter handle it.

-- RLS Policies
ALTER TABLE edit_requests ENABLE ROW LEVEL SECURITY;

-- Users can create requests
CREATE POLICY "Users can create edit requests" ON edit_requests
    FOR INSERT WITH CHECK (auth.uid() = requested_by);

-- Users can see their own requests
CREATE POLICY "Users can view their own edit requests" ON edit_requests
    FOR SELECT USING (auth.uid() = requested_by OR (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )));

-- Admins can see all requests
-- Included above via OR logic for safety

-- Admins can update requests (Approve/Reject)
CREATE POLICY "Admins can update edit requests" ON edit_requests
    FOR UPDATE USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));
