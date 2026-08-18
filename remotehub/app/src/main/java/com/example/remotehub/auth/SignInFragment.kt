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

class SignInFragment : Fragment() {

    private val authViewModel: AuthViewModel by viewModels()

    private lateinit var emailInput: TextInputEditText
    private lateinit var passwordInput: TextInputEditText
    private lateinit var signInButton: MaterialButton
    private lateinit var createAccountText: TextView

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {

        return inflater.inflate(
            R.layout.fragment_sign_in,
            container,
            false
        )
    }

    override fun onViewCreated(
        view: View,
        savedInstanceState: Bundle?
    ) {
        super.onViewCreated(view, savedInstanceState)

        emailInput = view.findViewById(R.id.etEmail)
        passwordInput = view.findViewById(R.id.etPassword)
        signInButton = view.findViewById(R.id.btnSignIn)
        createAccountText = view.findViewById(R.id.tvCreateAccount)

        signInButton.setOnClickListener {
            login()
        }

        createAccountText.setOnClickListener {
            findNavController().navigate(
                R.id.action_signInFragment_to_signUpFragment
            )
        }

        observeLoginState()
    }

    private fun login() {

        val email = emailInput.text
            ?.toString()
            ?.trim()
            .orEmpty()

        val password = passwordInput.text
            ?.toString()
            .orEmpty()

        if (email.isEmpty()) {
            emailInput.error = "Enter your email"
            emailInput.requestFocus()
            return
        }

        if (password.isEmpty()) {
            passwordInput.error = "Enter your password"
            passwordInput.requestFocus()
            return
        }

        authViewModel.login(
            email = email,
            password = password
        )
    }

    private fun observeLoginState() {

        viewLifecycleOwner.lifecycleScope.launch {

            viewLifecycleOwner.repeatOnLifecycle(
                Lifecycle.State.STARTED
            ) {

                authViewModel.loginState.collect { state ->

                    when (state) {

                        AuthOperationState.Idle -> {
                            signInButton.isEnabled = true
                        }

                        AuthOperationState.Loading -> {
                            signInButton.isEnabled = false
                        }

                        AuthOperationState.Success -> {

                            signInButton.isEnabled = true

                            findNavController().navigate(
                                R.id.action_signInFragment_to_homeFragment
                            )

                            authViewModel.resetLoginState()
                        }

                        is AuthOperationState.Error -> {

                            signInButton.isEnabled = true

                            Toast.makeText(
                                requireContext(),
                                state.message,
                                Toast.LENGTH_LONG
                            ).show()

                            authViewModel.resetLoginState()
                        }
                    }
                }
            }
        }
    }
}