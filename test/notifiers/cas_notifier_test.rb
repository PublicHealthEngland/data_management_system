require 'test_helper'

class CasNotifierTest < ActiveSupport::TestCase
  test 'should generate dataset_level_approved_status_updated Notifications' do
    project = create_cas_project(project_purpose: 'test')
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: true)
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                  approved: true)
    project_dataset.project_dataset_levels << pdl

    recipients = SystemRole.cas_manager_and_access_approvers.map(&:users).flatten
    title = 'Dataset Approval Level Status Change'
    assert_difference -> { Notification.by_title(title).count }, 4 do
      recipients.each do |user|
        CasNotifier.dataset_level_approved_status_updated(project, pdl, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS application #{project.id} - Dataset 'Extra CAS " \
                                         "Dataset One' has been updated to Approval status of " \
                                         "'Approved' for level 1.\n\n"
  end

  test 'should generate dataset_level_approved_status_updated_to_user Notifications' do
    project = create_cas_project(project_purpose: 'test',
                             owner: users(:no_roles))
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: true)
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                  approved: true)
    project_dataset.project_dataset_levels << pdl

    assert_difference -> { Notification.by_title('Dataset Approval Level Updated').count }, 1 do
      CasNotifier.dataset_level_approved_status_updated_to_user(project, pdl)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "Your CAS dataset access request for 'Extra CAS " \
                                         "Dataset One' has been updated to Approval status of " \
                                         "'Approved' for level 1.\n\n"
  end

  test 'should generate access_approval_status_updated Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = SystemRole.cas_manager_and_access_approvers.map(&:users).flatten

    # Auto-transition to Access granted makes this a bit tricky to test state_id here
    # although it is covered in project_state test
    title = 'Access Approval Status Updated'
    assert_difference -> { Notification.by_title(title).count }, 4 do
      recipients.each do |user|
        CasNotifier.access_approval_status_updated(project, user.id,
                                                   workflow_states(:access_approver_approved).id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS application #{project.id} - Access approval status has " \
                                         "been updated to 'Access Approver Approved'.\n\n"
  end

  test 'should generate account_approved_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)
    assert_difference -> { Notification.by_title('CAS Access Approved').count }, 1 do
      CasNotifier.account_approved_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'Your CAS access has been approved for application ' \
                                         "#{project.id}. You will receive a further notification " \
                                         "once your account has been updated.\n\n"
  end

  test 'should generate account_rejected_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)
    assert_difference -> { Notification.by_title('CAS Access Rejected').count }, 1 do
      CasNotifier.account_rejected_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'Your CAS access has been rejected for application ' \
                                         "#{project.id}.\n\n"
  end

  test 'should generate account_access_granted Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = User.cas_managers

    title = 'CAS Access Status Updated'
    assert_difference -> { Notification.by_title(title).count }, 2 do
      recipients.each do |user|
        CasNotifier.account_access_granted(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?
    expected = "CAS application #{project.id} - Access has been granted " \
               "by the helpdesk and the applicant now has CAS access.\n\n"
    assert_equal Notification.last.body, expected
  end

  test 'should generate account_access_granted_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)

    assert_difference -> { Notification.by_title('CAS Access Granted').count }, 1 do
      CasNotifier.account_access_granted_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'CAS access has been granted for your account based on ' \
                                         "application #{project.id}.\n\n"
  end

  test 'should generate requires_account_approval Notifications' do
    project = create_cas_project(project_purpose: 'test')
    title = 'CAS Application Requires Access Approval'
    assert_difference -> { Notification.by_title(title).count }, 2 do
      User.cas_access_approvers.each do |user|
        CasNotifier.requires_account_approval(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS application #{project.id} - Access approval is " \
                                         "required.\n\n"
  end

  test 'should generate requires_dataset_approval Notifications' do
    project = Project.new(project_type: ProjectType.find_by(name: 'CAS')).tap do |a|
      a.owner = users(:no_roles)
      a.project_datasets << ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
      a.project_datasets << ProjectDataset.new(dataset: dataset(84), terms_accepted: true)
      a.save!
    end
    title = 'CAS Application Requires Dataset Approval'
    assert_difference -> { Notification.by_title(title).count }, 3 do
      project.project_datasets.each do |project_dataset|
        project_dataset.dataset.approvers.each do |approver|
          CasNotifier.requires_dataset_approval(project, approver.id)
        end
      end
    end

    # TODO: Should it be creating UserNotifications?
    assert_equal Notification.last.body, "CAS application #{project.id} - Dataset approval is " \
                                         "required.\n\n"
  end

  test 'should generate application_submitted Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = User.cas_managers
    title = 'CAS Application Submitted'

    assert_difference -> { Notification.by_title(title).count }, 2 do
      recipients.each do |user|
        CasNotifier.application_submitted(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS project #{project.id} has been submitted.\n\n"
  end

  test 'should generate requires_renewal_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)

    assert_difference -> { Notification.by_title('CAS Access Requires Renewal').count }, 1 do
      CasNotifier.requires_renewal_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'Your access to CAS needs to be renewed, please visit ' \
                                         'your application to confirm renewal. If you have not ' \
                                         'renewed within 30 days your access will be removed and ' \
                                         "you will need to contact Beatrice Coker to reapply\n\n"
  end

  test 'should generate requires_renewal_midway_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)

    assert_difference -> { Notification.by_title('CAS Access Urgently Requires Renewal').count }, 1 do
      CasNotifier.requires_renewal_midpoint_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'Your access to CAS needs to be renewed, please visit ' \
                                         'your application to confirm renewal. If you have not ' \
                                         'renewed within 15 days your access will be removed and ' \
                                         "you will need to contact Beatrice Coker to reapply\n\n"
  end

  test 'should generate account_closed_to_user Notifications' do
    user = users(:no_roles)
    project = create_cas_project(project_purpose: 'test',
                             owner: user)

    assert_difference -> { Notification.by_title('CAS Account Closed').count }, 1 do
      CasNotifier.account_closed_to_user(project)
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, 'Your CAS account has been closed. If you still ' \
                                         'require access please re-apply using your existing ' \
                                         "application by clicking the 'return to draft' " \
                                         "button.\n\n"
  end

  test 'should generate account_closed Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = User.cas_managers
    title = 'CAS Account Has Closed'

    assert_difference -> { Notification.by_title(title).count }, 2 do
      recipients.each do |user|
        CasNotifier.account_closed(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS account #{project.id} has been closed.\n\n"
  end

  test 'should generate account_renewed Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = SystemRole.cas_manager_and_access_approvers.map(&:users).flatten

    title = 'CAS Account Renewed'
    assert_difference -> { Notification.by_title(title).count }, 4 do
      recipients.each do |user|
        CasNotifier.account_renewed(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS Account #{project.id} has been renewed.\n\n"
  end

  test 'should generate account_renewed_dataset_approver Notifications' do
    project = create_cas_project(owner: users(:no_roles))
    pd1 = ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
    pd2 = ProjectDataset.new(dataset: dataset(84), terms_accepted: true)
    project.project_datasets << pd1
    project.project_datasets << pd2
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    pd1.project_dataset_levels << pdl
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    pd2.project_dataset_levels << pdl
    project.save!

    title = 'CAS Account Renewed With Access to Dataset'
    assert_difference -> { Notification.by_title(title).count }, 3 do
      project.datasets.each do |dataset|
        dataset.approvers.each do |approver|
          CasNotifier.account_renewed_dataset_approver(project, approver.id)
        end
      end
    end

    # TODO: Should it be creating UserNotifications?
    assert_equal Notification.last.body, "CAS account #{project.id} has been renewed. This " \
                                         'account has access to one or more datasets that you ' \
                                         "are an approver for.\n\n"
  end

  test 'should generate new_cas_project_saved Notifications' do
    project = create_cas_project(project_purpose: 'test')

    recipients = User.cas_managers
    title = 'New CAS Application Created'

    assert_difference -> { Notification.by_title(title).count }, 2 do
      recipients.each do |user|
        CasNotifier.new_cas_project_saved(project, user.id)
      end
    end

    # TODO: Should it be creating UserNotifications?

    assert_equal Notification.last.body, "CAS application #{project.id} has been created.\n\n"
  end
end
