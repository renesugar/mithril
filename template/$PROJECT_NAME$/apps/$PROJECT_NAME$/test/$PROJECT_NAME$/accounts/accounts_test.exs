<% MixTemplates.ignore_file_and_directory_unless(assigns[:accounts] != nil) %>
defmodule <%= @project_name_camel_case %>.AccountsTest do
  use <%= @project_name_camel_case %>.DataCase

  import <%= @project_name_camel_case %>.AccountsFactory, only: [
    create_user: 1,
    create_token: 1,
    create_reset_password_token: 1,
    expire_token!: 1
  ]

  alias <%= @project_name_camel_case %>.{
    Accounts,
    Accounts.Token
  }

  @valid_user_params %{
    email: "test@example.com",
    password: "p@$$w0rd",
    password_confirmation: "p@$$w0rd"
  }

  describe ".create_user/1" do
    test "creates a user with valid parameters" do
      {:ok, user} = Accounts.create_user(@valid_user_params)
      assert user.email == "test@example.com"
      assert user.encrypted_password
    end

    test "returns errors if parameters are invalid" do
      # Completely blank params
      {:error, %{errors: errors}} = Accounts.create_user(%{})
      assert {:email, {"can't be blank", [validation: :required]}} in errors
      assert {:password, {"can't be blank", [validation: :required]}} in errors
      assert {:password_confirmation, {"can't be blank", [validation: :required]}} in errors

      # Invalid email
      {:error, %{errors: errors}} = Accounts.create_user(%{email: "invalid"})
      assert {:email, {"invalid email address", [validation: :format]}} in errors

      # Mismatching password
      {:error, %{errors: errors}} = 
        @valid_user_params
        |> Map.put(:password_confirmation, "mismatch")
        |> Accounts.create_user()

      assert {:password_confirmation, {"does not match confirmation", validation: :confirmation}} in errors
    end
  end

  describe ".tokenize/2" do
    setup [:create_user]

    test "returns a login token if credentials are valid" do
      assert {:ok, %Token{}} = Accounts.tokenize({"test@example.com", "p@$$w0rd"})
    end

    test "returns error if credentials are invalid" do
      assert {:error, :invalid_email} = Accounts.tokenize({"invalid@email.com", "p@$$w0rd"})
    end
  end

  describe ".authenticate/2" do
    setup [:create_user, :create_token]

    test "returns the user if token is valid", %{token: token, user: original_user} do
      assert {:ok, user} = Accounts.authenticate(token)
      assert user.id == original_user.id
    end

    test "returns error if token is invalid" do
      assert {:error, :invalid_token} = Accounts.authenticate(%Token{token: "invalid"})
    end
  end

  describe ".recover/1" do
    setup [:create_user]

    test "sends token if email is valid", %{user: user} do
      assert {:ok, _} = Accounts.recover(user.email)
      assert_received {:email, _email}
    end

    test "returns error if email is invalid" do
      assert {:error, :invalid_email} = Accounts.recover("nonexistent@email.com")
    end
  end

  describe ".update_user/2" do
    setup [:create_user, :create_reset_password_token]

    test "changes email if token is valid", %{token: token} do
      assert {:ok, user} =
        Accounts.update_user(%Token{token: token}, %{
          email: "new@email.com"
        })

      assert user.email == "new@email.com"
    end

    test "changes password if reset token is valid", %{user: user, token: token} do
      assert {:ok, _} = 
        Accounts.update_user(%Token{token: token}, %{
          password: "new_password",
          password_confirmation: "new_password"
        })

      assert {:ok, _token} = Accounts.tokenize({user.email, "new_password"})
    end

    test "returns validation errors if passwords don't match", %{token: token} do
      assert {:error, %Ecto.Changeset{errors: errors}} =
        Accounts.update_user(%Token{token: token}, %{
          password: "new_password",
          password_confirmation: "mismatch"
        })

      assert {:password_confirmation, {"does not match confirmation", [validation: :confirmation]}} in errors
    end

    test "returns error if reset token has expired", %{token: token} do
      expire_token!(token)
      
      assert {:error, :expired_token} =
        Accounts.update_user(%Token{token: token}, %{
          password: "new_password",
          password_confirmation: "new_password"
        })
    end

    test "returns error if reset token does not exist" do
      assert {:error, :invalid_token} = 
        Accounts.update_user(%Token{token: "nonexistent"}, %{
          password: "new_password",
          password_confirmation: "new_password"
        })
    end
  end
end