namespace :work_proof do
  desc "Auto-consolidate work proofs older than 4 hours"
  task auto_consolidate: :environment do
    puts "Starting auto-consolidation of old work proofs..."
    count = WorkProofConsolidationService.auto_consolidate_old_entries
    puts "Consolidated #{count} work proofs"
  end
  
  desc "Show work proofs needing consolidation"
  task check_pending: :environment do
    work_proofs = WorkProof.needs_auto_consolidation
    puts "Found #{work_proofs.count} work proofs needing consolidation:"
    work_proofs.each do |wp|
      hours = wp.work_hours || 0
      puts "  - WorkProof ##{wp.id}: #{wp.user_name} on #{wp.issue_subject} (#{hours}h)"
    end
  end
end

namespace :time_clocking do
  desc "Auto-consolidate time clockings older than 4 hours"
  task auto_consolidate: :environment do
    puts "Starting auto-consolidation of old time clockings..."
    count = TimeClockingConsolidationService.auto_consolidate_old_entries
    puts "Consolidated #{count} time clockings"
  end
  
  desc "Show time clockings needing consolidation"
  task check_pending: :environment do
    time_clockings = TimeClocking.needs_auto_consolidation
    puts "Found #{time_clockings.count} time clockings needing consolidation:"
    time_clockings.each do |tc|
      hours = tc.time_hours || 0
      puts "  - TimeClocking ##{tc.id}: #{tc.user_name} on #{tc.issue_subject} (#{hours}h)"
    end
  end
  
  desc "Auto-consolidate both work proofs and time clockings"
  task auto_consolidate_all: :environment do
    puts "Auto-consolidating work proofs and time clockings..."
    wp_count = WorkProofConsolidationService.auto_consolidate_old_entries
    tc_count = TimeClockingConsolidationService.auto_consolidate_old_entries
    puts "Consolidated #{wp_count} work proofs and #{tc_count} time clockings"
  end
end

