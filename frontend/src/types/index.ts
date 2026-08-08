export interface LineItem {
  item_code: string;
  description: string;
  quantity: number;
  unit_price: number;
  line_total: number;
}

export interface ExtractedData {
  vendor_name: string;
  vendor_tax_id?: string;
  invoice_number: string;
  po_number?: string;
  invoice_date: string;
  due_date?: string;
  currency: string;
  subtotal: number;
  tax_amount: number;
  total_amount: number;
  line_items: LineItem[];
  field_confidences: Record<string, number>;
  overall_confidence: number;
  raw_ocr_text?: string;
}

export interface LineMatchDetail {
  item_code: string;
  invoiced_qty: number;
  po_qty?: number;
  received_qty?: number;
  unit_price_variance: number;
  status: 'MATCHED' | 'PRICE_MISMATCH' | 'QUANTITY_MISMATCH' | 'UNRECEIVED';
}

export interface ThreeWayMatchResult {
  invoice_id: string;
  po_number?: string;
  match_status: 'FULL_MATCH' | 'PARTIAL_MATCH_WITHIN_TOLERANCE' | 'PRICE_MISMATCH' | 'QUANTITY_MISMATCH' | 'MISSING_PO' | 'MISSING_RECEIPT' | 'VENDOR_MISMATCH' | 'CURRENCY_MISMATCH';
  invoice_total: number;
  po_total?: number;
  received_total?: number;
  price_variance: number;
  quantity_variance: number;
  variance_percentage: number;
  within_tolerance: boolean;
  discrepancy_reasons: string[];
  line_level_matches: LineMatchDetail[];
  evaluated_at: string;
}

export interface ApprovalRequest {
  approval_id: string;
  invoice_id: string;
  requires_approval_reason: string;
  confidence_score: number;
  extracted_data?: ExtractedData;
  match_result?: ThreeWayMatchResult;
  status: 'PENDING' | 'RESOLVED' | 'EXPIRED';
  assigned_at: string;
}

export interface InvoiceUploadResponse {
  invoice_id: string;
  sha256_hash: string;
  filename: string;
  status: string;
  message: string;
  overall_confidence?: number;
  match_status?: string;
  requires_hitl: boolean;
  gl_reference_id?: string;
  error_message?: string;
}

export interface SystemHealthReport {
  status: string;
  service: string;
  timestamp: string;
  dependencies: {
    mock_erp: 'up' | 'down';
    mock_erp_url: string;
    postgres: string;
    redis: string;
    aws_textract: string;
    groq_llm: string;
  };
}
