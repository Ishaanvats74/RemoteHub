package com.example.remotehub.auth

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.example.remotehub.R
import kotlinx.coroutines.launch

class SplashFragment : Fragment() {

    private val authViewModel: AuthViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(
            R.layout.fragment_splash,
            container,
            false
        )
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        observeAuthentication()

        authViewModel.checkAuthentication()
    }

    private fun observeAuthentication() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {

                authViewModel.authState.collect { state ->

                    when (state) {

                        AuthState.Checking -> {
                            // Keep showing splash.
                        }

                        AuthState.Authenticated -> {
                            findNavController().navigate(
                                R.id.action_splashFragment_to_homeFragment
                            )
                        }

                        AuthState.Unauthenticated -> {
                            findNavController().navigate(
                                R.id.action_splashFragment_to_signInFragment
                            )
                        }
                    }
                }
            }
        }
    }
}