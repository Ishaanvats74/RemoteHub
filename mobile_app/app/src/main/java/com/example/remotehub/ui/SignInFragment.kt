package com.example.remotehub.ui

import android.os.Bundle
import android.util.Patterns
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import com.example.remotehub.R
import com.google.android.material.textfield.TextInputEditText

class SigninFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_signin, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val email = view.findViewById<TextInputEditText>(R.id.emailEditText)
        val password = view.findViewById<TextInputEditText>(R.id.passwordEditText)
        val signinButton = view.findViewById<Button>(R.id.signInButton)
        val signupLink = view.findViewById<TextView>(R.id.signup_link)

        signinButton.setOnClickListener {
            val emailText = email.text.toString().trim()
            val passwordText = password.text.toString()

            if (emailText.isEmpty()) {
                email.error = "Email required"
                return@setOnClickListener
            }

            if (!Patterns.EMAIL_ADDRESS.matcher(emailText).matches()) {
                email.error = "Invalid Email"
                return@setOnClickListener
            }

            if (passwordText.isEmpty()) {
                password.error = "Password required"
                return@setOnClickListener
            }

            Toast.makeText(
                context,
                "Signin Successful!",
                Toast.LENGTH_SHORT
            ).show()

            // Navigate to home
            findNavController().navigate(R.id.action_signinFragment_to_homeFragment)
        }

        signupLink.setOnClickListener {
            findNavController().navigate(R.id.action_signinFragment_to_signupFragment)
        }
    }
}