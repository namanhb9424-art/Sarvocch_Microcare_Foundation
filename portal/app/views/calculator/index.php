<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-calculator me-2"></i>MFI Loan EMI Calculator</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Interactive Reducing & Flat Rate Calculation</div>
  </div>
</div>

<div class="row g-4">
  <div class="col-12 col-lg-5">
    <div class="card shadow-sm border-0 border-top border-teal border-3">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Loan Parameters</h6>
      </div>
      <div class="card-body p-4">
        <div class="mb-3">
          <label class="form-label small fw-semibold">Principal Loan Amount (₹)</label>
          <input type="number" id="calcP" class="form-control" value="30000" step="1000" oninput="runCalc()">
        </div>

        <div class="mb-3">
          <label class="form-label small fw-semibold">Annual Interest Rate (% p.a.)</label>
          <input type="number" id="calcR" class="form-control" value="24.0" step="0.1" oninput="runCalc()">
        </div>

        <div class="mb-3">
          <label class="form-label small fw-semibold">Tenure (Months)</label>
          <select id="calcN" class="form-select" onchange="runCalc()">
            <option value="12">12 Months (1 Year)</option>
            <option value="18">18 Months (1.5 Years)</option>
            <option value="24" selected>24 Months (2 Years)</option>
            <option value="36">36 Months (3 Years)</option>
          </select>
        </div>

        <div class="mb-4">
          <label class="form-label small fw-semibold">Calculation Methodology</label>
          <select id="calcM" class="form-select" onchange="runCalc()">
            <option value="reducing">Reducing Balance (RBI Standard)</option>
            <option value="flat">Flat Interest Rate</option>
          </select>
        </div>

        <div class="p-3 bg-light rounded text-center">
          <div class="text-muted small text-uppercase">Monthly Equated Instalment (EMI)</div>
          <div class="display-6 fw-bold text-teal mt-1" id="resEmi">₹ 1,588.00</div>
          <div class="small text-muted mt-1" id="resSummary">Total Interest: ₹ 8,112.00</div>
        </div>
      </div>
    </div>
  </div>

  <div class="col-12 col-lg-7">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Simulated Amortization Schedule</h6>
      </div>
      <div class="table-responsive" style="max-height: 480px; overflow-y: auto;">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light sticky-top">
            <tr>
              <th>#</th>
              <th>Due Date</th>
              <th class="text-end">EMI (₹)</th>
              <th class="text-end">Principal</th>
              <th class="text-end">Interest</th>
              <th class="text-end">Balance</th>
            </tr>
          </thead>
          <tbody id="schedBody">
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<script>
function runCalc() {
  const p = parseFloat(document.getElementById('calcP').value) || 0;
  const r = parseFloat(document.getElementById('calcR').value) || 0;
  const n = parseInt(document.getElementById('calcN').value) || 12;
  const m = document.getElementById('calcM').value;

  fetch(`<?= url('/api/emi') ?>?p=${p}&r=${r}&n=${n}&m=${m}`)
    .then(res => res.json())
    .then(d => {
      document.getElementById('resEmi').innerText = '₹ ' + d.emi.toFixed(2);
      let totalInt = 0;
      let html = '';
      d.schedule.forEach(s => {
        totalInt += s.interest;
        html += `<tr>
          <td>${s.no}</td>
          <td>${s.due_date}</td>
          <td class="text-end fw-bold">₹ ${s.emi.toFixed(2)}</td>
          <td class="text-end">₹ ${s.principal.toFixed(2)}</td>
          <td class="text-end">₹ ${s.interest.toFixed(2)}</td>
          <td class="text-end fw-semibold">₹ ${s.balance.toFixed(2)}</td>
        </tr>`;
      });
      document.getElementById('resSummary').innerText = `Total Interest: ₹ ${totalInt.toFixed(2)} | Total Payment: ₹ ${(p + totalInt).toFixed(2)}`;
      document.getElementById('schedBody').innerHTML = html;
    });
}
document.addEventListener('DOMContentLoaded', runCalc);
</script>
