package com.dhana.amma.ui.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dhana.amma.AmmaApplication
import com.dhana.amma.R
import kotlinx.coroutines.launch

private data class TutorialPage(val icon: ImageVector, val titleRes: Int, val bodyResEn: Int, val bodyResTa: Int)

private val pages = listOf(
    TutorialPage(Icons.Filled.Mic, R.string.tutorial_page1_title, R.string.tutorial_page1_body_en, R.string.tutorial_page1_body_ta),
    TutorialPage(Icons.Filled.GraphicEq, R.string.tutorial_page2_title, R.string.tutorial_page2_body_en, R.string.tutorial_page2_body_ta),
    TutorialPage(Icons.Filled.Tv, R.string.tutorial_page3_title, R.string.tutorial_page3_body_en, R.string.tutorial_page3_body_ta),
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TutorialScreen(onComplete: () -> Unit) {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val languageCode = application.preferences.languageCode
    val childName = application.preferences.childName.ifBlank {
        if (languageCode == "ta") "அவங்க" else "them"
    }

    val pagerState = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()

    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        HorizontalPager(state = pagerState, modifier = Modifier.weight(1f)) { pageIndex ->
            val page = pages[pageIndex]
            val bodyRes = if (languageCode == "ta") page.bodyResTa else page.bodyResEn
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(page.icon, contentDescription = null, modifier = Modifier.size(64.dp))
                Spacer(Modifier.height(16.dp))
                Text(stringResource(page.titleRes), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
                Spacer(Modifier.height(8.dp))
                Text(stringResource(bodyRes, childName), style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
            horizontalArrangement = Arrangement.Center,
        ) {
            repeat(pages.size) { index ->
                val active = index == pagerState.currentPage
                Box(
                    modifier = Modifier
                        .padding(4.dp)
                        .size(8.dp)
                        .background(
                            color = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                            shape = CircleShape,
                        )
                )
            }
        }

        Button(
            onClick = {
                if (pagerState.currentPage < pages.size - 1) {
                    scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                } else {
                    application.preferences.hasSeenTutorial = true
                    onComplete()
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            val isLast = pagerState.currentPage == pages.size - 1
            Text(if (isLast) stringResource(R.string.tutorial_got_it) else stringResource(R.string.tutorial_next))
        }
    }
}
