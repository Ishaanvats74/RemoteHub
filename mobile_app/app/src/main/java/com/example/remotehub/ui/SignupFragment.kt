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

class SignupFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_signup, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val email = view.findViewById<TextInputEditText>(R.id.emailEditText)
        val password = view.findViewById<TextInputEditText>(R.id.passwordEditText)
        val signupButton = view.findViewById<Button>(R.id.signUpButton)
        val signinLink = view.findViewById<TextView>(R.id.signin_link)

        signupButton.setOnClickListener {
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
                "Signup Successful!",
                Toast.LENGTH_SHORT
            ).show()

            // Navigate to home or signin screen
            findNavController().navigate(R.id.action_signup_to_home)
        }

        signinLink.setOnClickListener {
            findNavController().navigate(R.id.action_signup_to_signin)
        }
    }
}