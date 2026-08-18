package com.example.remotehub.auth

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.example.remotehub.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

class SignUpFragment : Fragment() {

    private val authViewModel: AuthViewModel by viewModels()

    private lateinit var usernameInput: TextInputEditText
    private lateinit var emailInput: TextInputEditText
    private lateinit var passwordInput: TextInputEditText
    private lateinit var signUpButton: MaterialButton
    private lateinit var alreadyAccountText: TextView

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {

        return inflater.inflate(
            R.layout.fragment_sign_up,
            container,
            false
        )
    }

    override fun onViewCreated(
        view: View,
        savedInstanceState: Bundle?
    ) {
        super.onViewCreated(view, savedInstanceState)

        usernameInput = view.findViewById(R.id.etUsername)
        emailInput = view.findViewById(R.id.etEmail)
        passwordInput = view.findViewById(R.id.etPassword)
        signUpButton = view.findViewById(R.id.btnSignUp)
        alreadyAccountText = view.findViewById(R.id.tvAlreadyAccount)

        signUpButton.setOnClickListener {
            register()
        }

        alreadyAccountText.setOnClickListener {
            findNavController().navigate(
                R.id.action_signUpFragment_to_signInFragment
            )
        }

        observeRegisterState()
    }

    private fun register() {

        val username = usernameInput.text
            ?.toString()
            ?.trim()
            .orEmpty()

        val email = emailInput.text
            ?.toString()
            ?.trim()
            .orEmpty()

        val password = passwordInput.text
            ?.toString()
            .orEmpty()

        if (username.isEmpty()) {
            usernameInput.error = "Enter your username"
            usernameInput.requestFocus()
            return
        }

        if (username.length < 3) {
            usernameInput.error =
                "Username must be at least 3 characters"
            usernameInput.requestFocus()
            return
        }

        if (username.length > 30) {
            usernameInput.error =
                "Username must be at most 30 characters"
            usernameInput.requestFocus()
            return
        }

        if (email.isEmpty()) {
            emailInput.error = "Enter your email"
            emailInput.requestFocus()
            return
        }

        if (!android.util.Patterns.EMAIL_ADDRESS
                .matcher(email)
                .matches()
        ) {
            emailInput.error = "Enter a valid email"
            emailInput.requestFocus()
            return
        }

        if (password.isEmpty()) {
            passwordInput.error = "Enter your password"
            passwordInput.requestFocus()
            return
        }

        if (password.length < 6) {
            passwordInput.error =
                "Password must be at least 6 characters"
            passwordInput.requestFocus()
            return
        }

        authViewModel.register(
            username = username,
            email = email,
            password = password
        )
    }

    private fun observeRegisterState() {

        viewLifecycleOwner.lifecycleScope.launch {

            viewLifecycleOwner.repeatOnLifecycle(
                Lifecycle.State.STARTED
            ) {

                authViewModel.registerState.collect { state ->

                    when (state) {

                        AuthOperationState.Idle -> {
                            signUpButton.isEnabled = true
                        }

                        AuthOperationState.Loading -> {
                            signUpButton.isEnabled = false
                        }

                        AuthOperationState.Success -> {

                            signUpButton.isEnabled = true

                            Toast.makeText(
                                requireContext(),
                                "Account created successfully",
                                Toast.LENGTH_SHORT
                            ).show()

                            authViewModel.resetRegisterState()

                            findNavController().navigate(
                                R.id.action_signUpFragment_to_signInFragment
                            )
                        }

                        is AuthOperationState.Error -> {

                            signUpButton.isEnabled = true

                            Toast.makeText(
                                requireContext(),
                                state.message,
                                Toast.LENGTH_LONG
                            ).show()

                            authViewModel.resetRegisterState()
                        }
                    }
                }
            }
        }
    }
}