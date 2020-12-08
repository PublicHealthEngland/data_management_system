require 'test_helper'

# Tests behaviour of ProjectsMailer
class ProjectsMailerTest < ActionMailer::TestCase
  test 'dataset approved status updated' do
    project = create_project(project_type: project_types(:cas), project_purpose: 'test')
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: true, approved: true)
    project.project_datasets << project_dataset

    email = CasMailer.with(project: project, project_dataset: project_dataset).dataset_approved_status_updated

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal SystemRole.cas_manager_and_access_approvers.map(&:users).flatten.map(&:email), email.to
    assert_equal 'Dataset Approval Status Change', email.subject
    assert_match %r{a href="http://[^/]+/projects/#{project.id}"}, email.html_part.body.to_s
    assert_match %r{http://[^/]+/projects/#{project.id}}, email.text_part.body.to_s
  end

  test 'dataset approved status updated_to_user' do
    project = create_project(project_type: project_types(:cas), project_purpose: 'test')
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: true, approved: true)
    project.project_datasets << project_dataset

    email = CasMailer.with(project: project, project_dataset: project_dataset).dataset_approved_status_updated_to_user

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal Array.wrap(project.owner.email), email.to
    assert_equal 'Dataset Approval Updated', email.subject
    assert_match %r{http://[^/]+/projects/#{project.id}}, email.text_part.body.to_s
  end

  test 'access approval status updated' do
    project = create_project(project_type: project_types(:cas), project_purpose: 'test')
    project.transition_to!(workflow_states(:awaiting_account_approval))

    project.transition_to!(workflow_states(:approved))

    email = CasMailer.with(project: project).access_approval_status_updated

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal SystemRole.cas_manager_and_access_approvers.map(&:users).flatten.map(&:email), email.to
    assert_equal 'Access Approval Status Updated', email.subject
    assert_match %r{a href="http://[^/]+/projects/#{project.id}"}, email.html_part.body.to_s
    assert_match %r{http://[^/]+/projects/#{project.id}}, email.text_part.body.to_s
  end

  test 'account approved to user' do
    project = create_project(project_type: project_types(:cas), project_purpose: 'test',
                             owner: users(:no_roles))
    project.transition_to!(workflow_states(:awaiting_account_approval))

    project.transition_to!(workflow_states(:approved))

    email = CasMailer.with(project: project).account_approved_to_user

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal Array.wrap(project.owner.email), email.to
    assert_equal 'CAS Access Approved', email.subject
    assert_match %r{http://[^/]+/projects/#{project.id}}, email.text_part.body.to_s
  end

  test 'account access granted to user' do
    project = create_project(project_type: project_types(:cas), project_purpose: 'test',
                             owner: users(:no_roles))
    project.transition_to!(workflow_states(:approved))

    project.transition_to!(workflow_states(:access_granted))

    email = CasMailer.with(project: project).account_access_granted_to_user

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal Array.wrap(project.owner.email), email.to
    assert_equal 'CAS Access Granted', email.subject
    assert_match %r{http://[^/]+/projects/#{project.id}}, email.text_part.body.to_s
  end
end